# Possible NodeJS Spanner memory leak

This repository demonstrates a possible memory leak in the NodeJS Spanner library. As soon as a (read/write) transaction is initiated, it looks like some memory is leaked, or at least not reclaimed fast enough. Eventually closing the `Database` releases the memory, but obviously this defeats the purpose of re-using a pool of sessions.

## Set up

This example uses Cloud Functions, as this is how we noticed the memory leak in the first place. The Cloud Functions are triggered by Pub/Sub messages, but one could easily use a different trigger, like an HTTP endpoint. Dataflow is used to publish a decent amount of messages at a constant rate. Please choose a project on which you can be the owner to ease permissions setting.

Before running the scrips you must set the following environment variables:

```bash
export GCP_PROJECT_ID= # The ID of a GCP project that can be used to deploy the Cloud Functions.
export GCP_REGION= # The GCP region where the resources will be deployed.
export SPANNER_CONFIG= # The Spanner configuration, e.g. `regional-europe-west1`.
```

Also ensure application defaults are set, in order to run the Dataflow job:

```bash
gcloud auth application-default login
```

You can then run the `setup.sh` script, which will create the GCP resources and start the Dataflow job locally:

```bash
./deploy/setup.sh
```

## Deploy the Cloud Functions

You can deploy each Cloud Function by running:

```bash
./deploy/deploy-cf.sh <functionName>
```

`functionName` is one of:

- `readNoTransaction`
- `upsertNoTransaction`
- `readInTransaction`
- `upsertInTransaction`
- `sqlInTransaction`
- `readInSnapshot`
- `nopInTransaction`
- `nopInRolledBackTransaction`
- `nopInEndedTransaction`
- `closeTransaction`

## Look at memory usage

You can then head to Cloud Monitoring to compare the memory usage of the Cloud Functions:

```
fetch cloud_function
| metric 'cloudfunctions.googleapis.com/function/user_memory_bytes'
| filter
    (resource.function_name =~ 'memory-leak-.*')
| align delta(1m)
| every 1m
| group_by [resource.function_name],
    [value_user_memory_bytes_mean: mean(value.user_memory_bytes)]
```
