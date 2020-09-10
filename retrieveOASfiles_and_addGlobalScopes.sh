# -----------------------------------------Extracting swagger/openapi yaml files-------------------------------------------------------

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

# -----------------------------------------Extracting scopes from swagger/openapi yaml files and import them as global scopes -------------------------------------------------------
  while IFS= read -r line; do
    echo "HI-----$line"
    securitySchemes=$(niet components.'"securitySchemes"' $line -f json)
    echo "$securitySchemes"

    if [[ $securitySchemes != "Element not found"* ]]; then
        scopes=$(echo null | jq "$securitySchemes | ..|.scopes?|select(.)" | jq 'keys[] as $k | "\($k):delemeter:\(.[$k])"' | jq -r | sort -u)

        if [ ! -z "$scopes" ]; then
            echo "$scopes"
            echo "$scopes" >> scopeList.txt
            while IFS= read -r scope; do
                delimiter=:delemeter:
                s=$scope$delimiter
                scopeMap=();
                while [[ $s ]]; do
                scopeMap+=( "${s%%"$delimiter"*}" );
                s=${s#*"$delimiter"};
                done;

                scopeName=${scopeMap[0]##*/}
                description=${scopeMap[1]}

                curl -X POST "https://localhost:9443/api/am/publisher/v1/scopes" -H "accept: application/json" -H "Authorization: Basic YWRtaW46YWRtaW4=" -H "Content-Type: application/json" -d "{\"name\": \"${scopeName}\", \"displayName\": \"${scopeName}\", \"description\": \"${description}\", \"bindings\": [], \"usageCount\": 0}" -k
                
                findScopeString="${scopeMap[0]}: ${description}"
                replacedString="${scopeName}: ${description}"
                find . -wholename $line -print0 -o -name 'swagger.yaml' -print0 | xargs -0 perl -i -pe's'/$findScopeString/$replacedString/
        

            done < scopeList.txt
            rm scopeList.txt 
        fi
    fi
  done < openAPIFileList.txt
