set -e

FUNCTION_ENTRY_POINT=${1}
SERVICE_ACCOUNT_ID="memory-leak"
TOPIC_NAME="memory-leak-trigger"

REPO_ROOT=$(git rev-parse --show-toplevel)
FUNCTION_FOLDER=${REPO_ROOT}/functions
cd ${FUNCTION_FOLDER}

FUNCTION_MEMORY=256
FUNCTION_RUNTIME="nodejs14"
FUNCTION_SERVICE_ACCOUNT="${SERVICE_ACCOUNT_ID}@${GCP_PROJECT_ID}.iam.gserviceaccount.com"
FUNCTION_ENV_FILE="${REPO_ROOT}/deploy/env-vars.yml"
FUNCTION_NAME="memory-leak-${FUNCTION_ENTRY_POINT}"
MAX_INSTANCES=1

echo "Building and deploying ${FUNCTION_NAME}..."

npm install
npm run build

gcloud functions deploy \
  --project=${GCP_PROJECT_ID} \
  --region=${GCP_REGION} \
  --entry-point=${FUNCTION_ENTRY_POINT} \
  --ingress-settings=internal-only \
  --memory=${FUNCTION_MEMORY} \
  --max-instances=${MAX_INSTANCES} \
  --retry \
  --runtime=${FUNCTION_RUNTIME} \
  --service-account=${FUNCTION_SERVICE_ACCOUNT} \
  --source=. \
  --env-vars-file=${FUNCTION_ENV_FILE} \
  --trigger-topic=${TOPIC_NAME} \
  ${FUNCTION_NAME}

cd -
