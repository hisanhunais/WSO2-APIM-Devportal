#Add path to workspace project
cd /Users/hiranya/.jenkins/workspace/APIs_Import/
apictl login production -u admin -p admin -k
apictl vcs init
apictl vcs status -e production 

declare -a array=()

my_array=( $(find $PWD -type f | grep -e 'swagger.yaml' -e 'openapi.yaml') )
j=0
for i in "${!my_array[@]}"
do
   if [[ ${my_array[i]} != *"/wso2apictl_Project"* ]]; then
      array[j]="${my_array[i]}"
      j=$(( $j + 1 ))
   fi
done
printf "%s\n" "${array[@]}" > openAPIFileList.txt

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


# --------------------------------------Import modified and deleted projects--------------------------------------------------
# for k in "${!array[@]}"
i=0

while IFS= read -r line; do
      
      echo "\n path..." 
      echo "$line" 

      pathToProject="$(dirname "$line")/wso2apictl_*"
      projectName=$(dirname "$line")/wso2apictl_Project${i}

      apictl init "$projectName" --oas "$line" --initial-state=PUBLISHED

      cd $projectName/Meta-information
      # add empty array for gateway environments
      printf "environments: []" >> api.yaml

      # add enpoints url to api_params.yaml
      setEndpointUrls $line
      echo "produrl---"$PROD_ENV_PROD_URL
      echo "sandurl---"$PROD_ENV_SAND_URL

      find . -wholename 'api.yaml' -print0 -o -name 'api.yaml' -print0 | xargs -0 perl -i -pe's/productionUrl:/productionUrl: '${PROD_ENV_PROD_URL//\//\\/}/
      find . -wholename 'api.yaml' -print0 -o -name 'api.yaml' -print0 | xargs -0 perl -i -pe's/sandboxUrl:/sandboxUrl: '${PROD_ENV_SAND_URL//\//\\/}/

      # add image logo to project
      mkdir $projectName/Image
      cd $projectName/Image
      setImageUrls $line

      #reset to workspace path
      cd /Users/hiranya/.jenkins/workspace/APIs_Import

      apictl import-api -f $(dirname "$line")/wso2apictl_Project${i} -e production -k --update

      pathToProject="$(dirname "$line")/wso2apictl_*"
      git add "$pathToProject"
      i=$(( $i + 1 ))

done < openAPIFileList.txt

git status
git commit -m "commit-initialAPIImport"
apictl vcs deploy -e production
