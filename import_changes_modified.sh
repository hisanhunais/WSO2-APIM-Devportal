#!/bin/bash
PWD=`pwd`

envlist=$(apictl list envs --format "table {{.Name}}")
if ! [[ "$envlist" == *"production"* ]]; then
	apictl add-env -e production --apim  https://localhost:9443
fi

# apictl vcs init
apictl vcs status -e production

# -------Required configure the username, pasword in manage credentials---------
# withCredentials([usernamePassword(credentialsId: 'apim_dev', usernameVariable: 'DEV_USERNAME', passwordVariable: 'DEV_PASSWORD')]) {
#                   sh 'apictl login $DEV_ENV -u $DEV_USERNAME -p $DEV_PASSWORD -k'                        
#}
apictl login production -u admin -p admin -k


lastBuildcommitId=$(cat lastSuccesfulBuildCommit.txt)
lastCommitId=$(git rev-parse HEAD)

git diff "$lastBuildcommitId" "${lastCommitId}" --name-only --diff-filter=D > deletedfiles.txt
git diff "$lastBuildcommitId" "${lastCommitId}" --name-only --diff-filter=AM > modifiedfiles.txt

# ----------------------------------------Set End point Urls to project-------------------------------------------------------
setEndpointUrls() {
   if [[ $1 == *"openapi.yaml" ]]; then
      urlString=$(niet ".servers" $1)
      if [[ $urlString != "Element not found"* ]]; then
         url=$(jq -r '.url' <(echo "${urlString//\'/\"}"))
         url |
         while read -r value
         do
            if [ -z "$productionURL" ]; then
               productionURL=${value}
            else
               sandBoxURL=${value}
            fi
         done
      else
         productionURL=$(niet info.'"x-providerName"' $1)
      fi
   else
      schemes=$(niet ".schemes" $1)
      basePath=$(niet ".basePath" $1)
      host=$(niet ".host" $1)

      if [[ $host == "Element not found"* ]]; then
         host=$(niet info.'"x-providerName"' $1)
      fi

      if [[ $basePath == "Element not found"* ]]; then
         basePath={}
      fi

      if [[ $schemes == "Element not found"* ]]; then
         productionURL=$host$basePath
      else
         schemes |
         while read -r scheme
         do
            if [ -z "$productionURL" ]; then
               productionURL=${scheme}"://"$host$basePath
            else
               sandBoxURL=${scheme}"://"$host$basePath
            fi
         done
      fi

   fi

   echo "--------$1---------" 
   echo "productionURL: $productionURL" 
   echo "sandBoxURL: $sandBoxURL" 
   export PROD_ENV_PROD_URL=$productionURL
   export PROD_ENV_SAND_URL=$sandBoxURL
}

# -----------------------------------------Download images to add project-------------------------------------------------------
setImageUrls() {
   imageURL=$(niet info.'"x-logo"' $1)

   if [[ $imageURL != "Element not found"* ]] && [[ $imageURL == *".jpg" || $imageURL == *".svg" || $imageURL == *".png" || $imageURL == *".jpeg" ]] ; then
      wget ${imageURL#*: }
   fi
}


import_changes () {
  # Import modified and added swagger files
  declare -a array=()
  i=0
  echo "$1"

  # reading file in row mode, insert each line into array
  while IFS= read -r line; do
      if [[ $line == *".yaml"* ]] && [[ $line != *"wso2apictl_"* ]]; then
          array[i]="$line"
          echo "Added-${array[i]}"
          i=$(( $i + 1 ))
      fi
  done < "$1"

  for j in "${!array[@]}"
    do
      swaggerPath="${array[j]}"
      pathToProject="$(dirname "${swaggerPath}")/wso2apictl_*"

      echo "pathToSwaggerFile-${swaggerPath}"
      echo "******pathToProject-$PWD/$pathToProject"
      result=$(find . -name $PWD/$pathToProject)
      
      rm -rf "$pathToProject"

      if [ $1 == "modifiedfiles.txt" ]; then
         echo "HI"
         echo "pathToProject-$pathToProject"
         pathToProject="$(dirname "${swaggerPath}")/wso2apictl_Project${j}"
         apictl init "$PWD/$pathToProject" --oas "$PWD/$swaggerPath" --initial-state=PUBLISHED

         cd $pathToProject/Meta-information
         # add empty array for gateway environments
         printf "environments: []" >> api.yaml

         # add enpoints url to api_params.yaml
         setEndpointUrls $swaggerPath
         echo "produrl---"$PROD_ENV_PROD_URL
         echo "sandurl---"$PROD_ENV_SAND_URL
         
         find . -wholename 'api.yaml' -print0 -o -name 'api.yaml' -print0 | xargs -0 perl -i -pe's/productionUrl:/productionUrl: '${PROD_ENV_PROD_URL//\//\\/}/
         find . -wholename 'api.yaml' -print0 -o -name 'api.yaml' -print0 | xargs -0 perl -i -pe's/sandboxUrl:/sandboxUrl: '${PROD_ENV_SAND_URL//\//\\/}/

         # add image logo to project
         mkdir $pathToProject/Image
         cd $pathToProject/Image
         setImageUrls $swaggerPath
      fi

      echo "pathToProject-$pathToProject"
      git add "$(dirname "${swaggerPath}")"

      # apictl import-api -f "$PWD/${projectName}" -e production -k --preserve-provider --update --verbose
    done
}


import_changes deletedfiles.txt
import_changes modifiedfiles.txt

git status
git commit -m "commit-${lastCommitId}"
apictl vcs deploy -e production

rm deletedfiles.txt
rm modifiedfiles.txt
perl -pi -e "s/$lastBuildcommitId/$lastCommitId/g" lastSuccesfulBuildCommit.txt
