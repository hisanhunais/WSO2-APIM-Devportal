# Deploying Public APIs to WSO2 APIM Devportal

cicd-public-apis import for WSO2 Devportal 

**Requirement
Install Jenkin
pip install niet==2.2.0
pip install json-query  

1. Configure a Jenkin build for https://github.com/HiranyaKavishani/openapi-directory.git

2. Configure a github webhook (Can use Ngrok to connect with localhost) 

3. Execute "retrieveOASfiles_and_addGlobalScopes.sh" on the workspace project

4. Execute "initialscript.sh" on the workspace project which will create API Projects from existing files and deploy them to developer portal

5. Store the last commit Id in to a file > lastSuccesfulBuildCommit.txt

6. Configure https://github.com/HiranyaKavishani/WSO2-APIM-Devportal/blob/master/Jenkinsfile pipeline and execute import-new-changes.sh to add new changes
