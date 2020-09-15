# Deploying Public APIs to WSO2 APIM Devportal

cicd-public-apis import for WSO2 Devportal 

**Requirements**

* Install Jenkin
* pip install niet==2.2.0
* pip install json-query  

1. Configure a Jenkin build for https://github.com/HiranyaKavishani/openapi-directory.git

2. Configure a github webhook (Can use Ngrok to connect with localhost) 

   optional: Execute "retrieveOASfiles_and_addGlobalScopes.sh" on the workspace project to create global scopes

3. Execute "initial_script_modified.sh" on the workspace project which will create API Projects from existing files and deploy them to developer portal

4. Store the last commit Id in to a file > lastSuccesfulBuildCommit.txt and place it in to workspace project

5. Configure https://github.com/HiranyaKavishani/WSO2-APIM-Devportal/blob/master/Jenkinsfile pipeline and execute import-new-changes.sh to add new changes
