TOPIC_NAME="memory-leak-trigger"
TOPIC_ID="projects/${GCP_PROJECT_ID}/topics/${TOPIC_NAME}"
GS_BUCKET="mem-leak-$(openssl rand -hex 3)"
SERVICE_ACCOUNT_ID="memory-leak"
SERVICE_ACCOUNT="${SERVICE_ACCOUNT_ID}@${GCP_PROJECT_ID}.iam.gserviceaccount.com"
PUBLISHING_RATE=10
SPANNER_INSTANCE="memory-leak"
SPANNER_DATABASE="memory-leak"

set -e

echo "GCP project: ${GCP_PROJECT_ID}"
echo "GCP region: ${GCP_REGION}"

# Create the Pub/Sub topic.
echo "Creating topic ${TOPIC_NAME}..."
gcloud pubsub topics create --project ${GCP_PROJECT_ID} ${TOPIC_NAME}

# Create the Storage bucket (used by Dataflow).
echo "Creating bucket ${GS_BUCKET}..."
gsutil mb -p ${GCP_PROJECT_ID} -l ${GCP_REGION} gs://${GS_BUCKET}

# Create a service account used by both Dataflow and Cloud Functions.
echo "Creating service account ${SERVICE_ACCOUNT_ID}..."
gcloud iam service-accounts create ${SERVICE_ACCOUNT_ID} \
    --project ${GCP_PROJECT_ID} \
    --display-name=${SERVICE_ACCOUNT_ID}
gcloud projects add-iam-policy-binding ${GCP_PROJECT_ID} \
    --member "serviceAccount:${SERVICE_ACCOUNT}" \
    --role "roles/spanner.databaseUser"
gcloud projects add-iam-policy-binding ${GCP_PROJECT_ID} \
    --member "serviceAccount:${SERVICE_ACCOUNT}" \
    --role "roles/dataflow.worker"
gcloud projects add-iam-policy-binding ${GCP_PROJECT_ID} \
    --member "serviceAccount:${SERVICE_ACCOUNT}" \
    --role "roles/pubsub.publisher"
gcloud projects add-iam-policy-binding ${GCP_PROJECT_ID} \
    --member "serviceAccount:${SERVICE_ACCOUNT}" \
    --role "roles/storage.objectAdmin"

# Set up Spanner.
echo "Creating Spanner instance ${SPANNER_INSTANCE} and database ${SPANNER_DATABASE}..."
gcloud spanner instances create ${SPANNER_INSTANCE} \
    --project ${GCP_PROJECT_ID} \
    --config ${SPANNER_CONFIG} \
    --description "Memory leak example"\
    --nodes 1
gcloud spanner databases create ${SPANNER_DATABASE} \
    --instance ${SPANNER_INSTANCE} \
    --ddl "CREATE TABLE myEntity (id STRING(36) NOT NULL, value INT64 NOT NULL) PRIMARY KEY (id)"

# Deploy the Dataflow job.
echo "Deploying the Dataflow job..."

REPO_ROOT=$(git rev-parse --show-toplevel)
cd ${REPO_ROOT}/publisher

DATAFLOW_ARGS="--streaming --runner=DataflowRunner --serviceAccount=${SERVICE_ACCOUNT} --project=${GCP_PROJECT_ID} --qps=${PUBLISHING_RATE} --topic=${TOPIC_ID} --region=${GCP_REGION} --tempLocation=gs://${GS_BUCKET}/temp/"
gradle run -DmainClass=com.epoca.Generator -Pargs="${DATAFLOW_ARGS}"

cd -
