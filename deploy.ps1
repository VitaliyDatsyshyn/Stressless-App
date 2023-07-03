$group = "StresslessApp"
$location = "westeurope"
$environment = "stressless-env"
$storage_account = "stresslessstorage1"
$servicebus_namespace = "stresslessservicebus1"
$queue = "feedback-queue"

# creating resource group
az group create --name $group `
				--location $location

# creating storage account
az storage account create --name $storage_account `
						  --resource-group $group `
						  --location $location `
						  --sku Standard_RAGRS `
						  --kind StorageV2

$storageKey = (az storage account keys list --account-name $storage_account --resource-group $group --output json --query "[0].value")

# replace secret placeholders
(Get-Content "statestore.yml").replace('"STORAGE_ACCOUNT_KEY"', $storageKey) | Set-Content "statestore.yml"
(Get-Content "statestore.yml").replace('STORAGE_NAME', $storage_account) | Set-Content "statestore.yml"

# creating service bus
az servicebus namespace create --resource-group $group --name $servicebus_namespace --location $location

az servicebus queue create --resource-group $group --namespace-name $servicebus_namespace --name $queue

$serviceBusConnectionString = (az servicebus namespace authorization-rule keys list --resource-group $group --namespace-name $servicebus_namespace `
				--name RootManageSharedAccessKey --query primaryConnectionString --output json)

# replace secret placeholders
(Get-Content "pubsub.yml").replace('"CONNECTION_STRING"', $serviceBusConnectionString) | Set-Content "pubsub.yml"

# creating environment
az containerapp env create --name $environment `
                           --resource-group $group `
                           --internal-only false `
                           --location $location
		
# setting dapr state store
az containerapp env dapr-component set `
--name $environment --resource-group $group `
--dapr-component-name statestore `
--yaml '.\statestore.yml'

# setting dapr pub/sub
az containerapp env dapr-component set `
--name $environment --resource-group $group `
--dapr-component-name pubsub `
--yaml '.\pubsub.yml'

az containerapp env dapr-component list --resource-group $group --name $environment --output json

# replace back secrets on placeholders
(Get-Content "statestore.yml").replace($storageKey, '"STORAGE_ACCOUNT_KEY"') | Set-Content "statestore.yml"
(Get-Content "statestore.yml").replace($storage_account, 'STORAGE_NAME') | Set-Content "statestore.yml"
(Get-Content "pubsub.yml").replace($serviceBusConnectionString, '"CONNECTION_STRING"') | Set-Content "pubsub.yml"

# build images
docker build -t datsyshyn09/stresslessapp -f 'StresslessApp\Dockerfile' .
docker push datsyshyn09/stresslessapp

docker build -t datsyshyn09/stresslessappfeedbackcollector -f 'StresslessApp.FeedbackCollector\Dockerfile' .
docker push datsyshyn09/stresslessappfeedbackcollector

docker build -t datsyshyn09/stresslessapppostgenerator -f 'StresslessApp.PostGenerator\Dockerfile' .
docker push datsyshyn09/stresslessapppostgenerator

# creating the StresslessApp
az containerapp create `
  --name stresslessapp `
  --resource-group $group `
  --environment $environment `
  --image datsyshyn09/stresslessapp:latest `
  --target-port 80 `
  --ingress 'external' `
  --min-replicas 0 `
  --max-replicas 5 `
  --enable-dapr `
  --env-vars ASPNETCORE_ENVIRONMENT="Development" `
  --dapr-app-port 80 `
  --dapr-app-id stresslessapp
  
# creating the StresslessApp.FeedbackCollector
az containerapp create `
  --name stresslessapp-feedbackcollector `
  --resource-group $group `
  --environment $environment `
  --image datsyshyn09/stresslessappfeedbackcollector:latest `
  --target-port 80 `
  --ingress 'internal' `
  --min-replicas 0 `
  --max-replicas 5 `
  --enable-dapr `
  --secrets connection-string=$serviceBusConnectionString `
  --scale-rule-name azure-servicebus-queue-rule `
  --scale-rule-type azure-servicebus `
  --scale-rule-metadata queueName=$queue `
						namespace=$servicebus_namespace `
						messageCount=5 `
  --scale-rule-auth connection=connection-string `
  --env-vars ASPNETCORE_ENVIRONMENT="Development" ConnectionString=secretref:connection-string `
  --dapr-app-port 80 `
  --dapr-app-id stresslessapp-feedbackcollector
  
# creating the StresslessApp.PostGenerator
az containerapp create `
  --name stresslessapp-postgenerator `
  --resource-group $group `
  --environment $environment `
  --image datsyshyn09/stresslessapppostgenerator:latest `
  --target-port 80 `
  --ingress 'internal' `
  --min-replicas 0 `
  --max-replicas 5 `
  --enable-dapr `
  --env-vars ASPNETCORE_ENVIRONMENT="Development" `
  --dapr-app-port 80 `
  --dapr-app-id stresslessapp-postgenerator