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


function parse_yaml {
   local prefix=$2
   local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')
   gsed -ne "s|,$s\]$s\$|]|" \
        -e ":1;s|^\($s\)\($w\)$s:$s\[$s\(.*\)$s,$s\(.*\)$s\]|\1\2: [\3]\n\1  - \4|;t1" \
        -e "s|^\($s\)\($w\)$s:$s\[$s\(.*\)$s\]|\1\2:\n\1  - \3|;p" $1 | \
   gsed -ne "s|,$s}$s\$|}|" \
        -e ":1;s|^\($s\)-$s{$s\(.*\)$s,$s\($w\)$s:$s\(.*\)$s}|\1- {\2}\n\1  \3: \4|;t1" \
        -e    "s|^\($s\)-$s{$s\(.*\)$s}|\1-\n\1  \2|;p" | \
   gsed -ne "s|^\($s\):|\1|" \
   	-e "s|^\($s\)-$s[\"']\(.*\)[\"']$s\$|\1$fs$fs\2|p" \
	-e "s|^\($s\)-$s\(.*\)$s\$|\1$fs$fs\2|p" \
        -e "s|^\($s\)\($w\)$s:$s[\"']\(.*\)[\"']$s\$|\1$fs\2$fs\3|p" \
        -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p" | \
   gawk -F$fs '{
      indent = length($1)/2;
      vname[indent] = $2;
      for (i in vname) {if (i > indent) {delete vname[i]; idx[i]=0}}
      if(length($2)== 0){  vname[indent]= ++idx[indent] };
      if (length($3) > 0) {
         vn=""; for (i=0; i<indent; i++) { vn=(vn)(vname[i])("_")}
         printf("%s%s%s=\"%s\"\n", "'$prefix'",vn, vname[indent], $3);
      }
   }'
}


setEndpointUrls() {
   echo "file-$1"
   gsed -i "s/\`/'/g" $1
   eval $(parse_yaml $1 'conf_')

   if [[ $1 == *"openapi.yaml" ]]; then
   productionURL=${conf_servers_1#*:}
      if [ -z "$conf_servers_2" ]; then
      sandBoxURL=${conf_servers_2#*:}
      fi

   else
      if [ -z "$conf_schemes_1" ]; then
      productionURL=$conf_host$conf_basePath
      else
      productionURL=$conf_schemes_1"://"$conf_host$conf_basePath
      fi
   fi

   echo "--------$1---------" 
   echo "productionURL: $productionURL" 
   echo "sandBoxURL: $sandBoxURL" 
   export PROD_ENV_PROD_URL=$productionURL
   export PROD_ENV_SAND_URL=$sandBoxURL
}

setImageUrls() {
  eval $(parse_yaml $1 'conf_')
  imageUrls=$conf_info_version_url
  if [[ $imageUrls == *".svg"* || $imageUrls == *".jpg"* || $imageUrls == *".png"* || $imageUrls == *".jpeg"* ]]; then
      wget $imageUrls
      echo "image...downloaded-$imageUrls" 
  fi
  echo "image...$1" 
  ls
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
      
      #if [[ -z $result ]]; then
      #echo "Found"
      #rm -rf $pathToProject
      #ls
      #fi
      rm -rf "$pathToProject"

      if [ $1 == "modifiedfiles.txt" ]; then
        echo "HI"
        echo "pathToProject-$pathToProject"
        pathToProject="$(dirname "${swaggerPath}")/wso2apictl_Project${j}"
        apictl init "$PWD/$pathToProject" --oas "$PWD/$swaggerPath" --initial-state=PUBLISHED
      
        # add empty array for gateway environments
        printf "environments: []" >> $(dirname "$swaggerPath")/wso2apictl_Project${i}/Meta-information/api.yaml

        # add endpoint urls to environments
        cp -f api_params.yaml $(dirname "$swaggerPath")/wso2apictl_Project${i}/api_params.yaml
        setEndpointUrls $swaggerPath

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
# import_changes modifiedfiles.txt

git status
git commit -m "commit-${lastCommitId}"
apictl vcs deploy -e production

# rm deletedfiles.txt
# rm modifiedfiles.txt
perl -pi -e "s/$lastBuildcommitId/$lastCommitId/g" lastSuccesfulBuildCommit.txt
