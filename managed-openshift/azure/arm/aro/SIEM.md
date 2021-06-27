# Connect ARO to LogAnalytics and then to Azure Sentinel

## Prerequisites:
* Azure CLI
* Openshift CLI
* Helm

## Steps
* Create a [Log Analytics workspace](https://portal.azure.com/#create/Microsoft.LogAnalyticsOMS)
* Get the Resource ID for both the Log Analytics Workspace created and the ARO cluster:
    ```bash
    az resource list --resource-type Microsoft.OperationalInsights/workspaces -o json
    az resource list --resource-type Microsoft.RedHatOpenShift/openShiftClusters -o json
    ```
* Set environment variables
    ```bash
    export logAnalyticsWorkspaceResourceId="<logAnalyticsWorkspaceResourceId>"
    export azureAroV4ClusterResourceId="<azureAroV4ClusterResourceId>"
    ```
* Set Openshift Config context as environmental variable
    ```bash
    export kubeContext=$(oc config current-context)
    ```
* Download and Run Azure monitoring script
    ```bash
    curl -o enable-monitoring.sh -L https://aka.ms/enable-monitoring-bash-script
    bash enable-monitoring.sh --resource-id $azureAroV4ClusterResourceId --kube-context $kubeContext --workspace-id $logAnalyticsWorkspaceResourceId
    ```
* Go to Azure Sentinel and Connect to the Workspace