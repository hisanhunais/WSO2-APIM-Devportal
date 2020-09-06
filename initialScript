#Add path to work space project
#cd /Users/hiranya/.jenkins/workspace/Public-API-Import

declare -a array=()

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


my_array=( $(find $PWD -type f | grep -e 'swagger.yaml' -e 'openapi.yaml') )
j=0
for i in "${!my_array[@]}"
do
   if [[ ${my_array[i]} != *"/wso2apictl_Project"* ]]; then
      array[j]="${my_array[i]}"
      j=$(( $j + 1 ))
   fi
done

apictl vcs init
#apictl vcs status -e production 
# for i in "${!my_array[@]}" 


# for i in "${!array[@]}"
for ((i = 2479 ; i <= 3077 ; i++));
do
   echo "\n path..." 
   echo "${array[i]}" 

   pathToProject="$(dirname "${array[i]}")/wso2apictl_*"

   apictl init "$(dirname "${array[i]}")/wso2apictl_Project${i}" --oas "${array[i]}" --initial-state=PUBLISHED

   # add empty array for gateway environments
   printf "environments: []" >> $(dirname "${array[i]}")/wso2apictl_Project${i}/Meta-information/api.yaml

   #dynamically add enpoints url to api_params.yaml
   # cd ..
   cp -f api_params.yaml $(dirname "${array[i]}")/wso2apictl_Project${i}/api_params.yaml
   setEndpointUrls ${array[i]}

   # add image logo to project
   mkdir $(dirname "${array[i]}")/wso2apictl_Project${i}/Image
   cd $(dirname "${array[i]}")/wso2apictl_Project${i}/Image
   setImageUrls ${array[i]}

   #reset to workspace path
   #cd /Users/hiranya/.jenkins/workspace/Public-API-Import

   # apictl import-api -f /Users/hiranya/Projects/APIM/openapi-directory/APIs/${projectName} -e production -k --update
   pathToProject="$(dirname "${array[i]}")/wso2apictl_*"
   git add "$pathToProject"
done

git status
git commit -m "commit-initialAPIImport"
apictl vcs deploy -e production
