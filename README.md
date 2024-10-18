# ACA cheat-sheet

To deploy new revision and shift all new traffic to it:

```bash

API_NAME="grf-spring-api" && LOCATION="australiaeast" && ENVIRONMENT="managedEnvironment-grfacaspringasp-a46c" && RESOURCE_GROUP="grf-aca-spring-aspire-test" && az containerapp up --name $API_NAME --location $LOCATION --environment $ENVIRONMENT --source .

```

To deploy new revision with no traffic (assuming multi-revisions enabled)

```bash

API_NAME="grf-dotnet-web" && LOCATION="australiaeast" && ENVIRONMENT="managedEnvironment-grfacaspringasp-a46c" && RESOURCE_GROUP="grf-aca-spring-aspire-test" && echo $API_NAME && az containerapp update --name $API_NAME --resource-group $RESOURCE_GROUP --source .

API_NAME="grf-dotnet-web" && LOCATION="australiaeast" && ENVIRONMENT="managedEnvironment-grfacaspringasp-a46c" && RESOURCE_GROUP="grf-aca-spring-aspire-test" && echo $API_NAME && az containerapp ingress traffic set -n $API_NAME -g $RESOURCE_GROUP  --revision-weight latest=20

```



