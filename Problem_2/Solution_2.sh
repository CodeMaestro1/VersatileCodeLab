#!/bin/bash  

####This section is responsible for the creation of the database and the tables####
#Declare the associative arrays that we will need:
declare -A categories_doc
declare -A doc_term
declare -A stem_term
declare -A doc_category
declare -A term_stem
declare -A jaccard_index

# Define a function to check if a file is valid  
is_valid_file() {  
    file_name=$1  
    if [ ! -f "$file_name" ]
    then  
        echo "The file $file_name must be a valid string path."  
        exit 1  
    fi  
}

######################################Processing the files started#############################################
read_categories_from_file() {  
    is_valid_file "$1"  

    while IFS= read -r line; do  
        local elements  
        IFS=' ' read -ra elements <<< "$line"  
        local key=${elements[0]}  
        local documents=("${elements[@]:1:2}")  # Only read the first two elements
        categories_doc["$key"]+="${documents[*]} "  # Append new values to the existing ones
    done < "$1"  

    echo "Categories file has been stored"  
}

# Function to read documents from a file
read_terms_from_document_file() {
    declare -n documents_array=$2 # Create a nameref to the associative array

    while IFS= read -r line || [[ -n $line ]]
    do
        # Extract document id
        doc_id=$(echo "$line" | cut -d' ' -f1)

        # Process each term in the line
        for term_value in $(echo "$line" | cut -d' ' -f2-)
        do
            # Extract term without value
            term=$(echo "$term_value" | cut -d':' -f1)

            # Append the term to the existing ones under the doc_id key
            documents_array["$doc_id"]+="$term "
        done
    done < "$1"

    echo "Documents file has been stored"
}

read_stem_term_pairs() {
    local file_to_read_stem_term_pairs=$1

    # Remove carriage return characters. 
    # This is necessary because the file was created in Windows.
    local stem_term_unix="${file_to_read_stem_term_pairs}_unix.txt"
    tr -d '\r' < "$file_to_read_stem_term_pairs" > "$stem_term_unix"

    while IFS=' ' read -r stem term rest 
    do
        if [[ -n $term ]]
        then
            stem_term["$stem"]="$term"
            #echo "Term: $term, Stem: $stem"
        fi
    done <"$stem_term_unix"
}
######################################Processing the files ended#############################################


######################################Define some helper functions for the P and C operations#############################################
populate_doc_category() {
    is_valid_file "$1"

    # No need to create a nameref, directly use the global associative array
    while IFS= read -r line
    do
        local elements
        IFS=' ' read -ra elements <<< "$line"
        local category=${elements[0]}
        local documents=("${elements[@]:1}")  # Read all elements after the first one
        for doc in "${documents[@]}"
        do
            if [[ -n ${doc_category["$doc"]} ]]
            then
                # If the document already has a category, append the new category
                doc_category["$doc"]+=", $category"
            else
                # If the document doesn't have a category yet, assign the new category
                doc_category["$doc"]="$category"
            fi
        done
    done < "$1"

    echo "Document-category array has been populated"
}

read_stem_term_pairs_helper() {

    local file_to_read_stem_term_pairs=$1

    local stem_term_unix_helper="${file_to_read_stem_term_pairs}_unix_helper.txt"

    # Remove carriage return characters. 
    # This is necessary because the file was created in Windows.
    tr -d '\r' < "$file_to_read_stem_term_pairs" > "$stem_term_unix_helper" 

    while IFS=' ' read -r stem term rest 
    do
        if [[ -n $term ]]
        then
            term_stem["$term"]="$stem"
        fi
    done <"$stem_term_unix_helper"
}

######################################Define some helper functions for the P and C operations#############################################


##########Calculate Jaccard Index##########

calculate_jaccard_index() {
    for stem in "${!stem_term[@]}"
    do
        term=${stem_term[$stem]}
        term_docs=()
        while IFS= read -r line
        do
            term_docs+=("$line")
        done < <(get_doc_with_term doc_term "$term")

        ###########################echo "term_docs: ${term_docs[*]}"  #For debugging purposes###########################
        

        for category in "${!categories_doc[@]}"
        do
            IFS=' ' read -r -a my_category_docs <<< "${categories_doc[$category]}"

            # Calculate intersection and union of term_docs and my_category_docs
            # Populate intersection and union
            intersection=($(printf "%s\n" "${term_docs[@]}" "${my_category_docs[@]}" | sort | uniq -d))
            union=($(printf "%s\n" "${term_docs[@]}" "${my_category_docs[@]}" | sort | uniq))

            intersection_count=${#intersection[@]}

            union_count=${#union[@]}

            if (( union_count > 0 )); then
                jaccard_index["${stem}_${category}"]=$(awk -v num="$intersection_count" -v denom="$union_count" 'BEGIN { printf "%.2f", num / denom }')
                #echo "Jaccard index: ${jaccard_index["${stem}_${category}"]} for the stem $stem, term $term, category $category"
            else
                jaccard_index["${stem}_${category}"]=0
            fi
        done
    done
}

get_doc_with_term() {
    search_term=$2
    docs_with_term=()

    for doc in "${!doc_term[@]}"
    do
        if echo "${doc_term[$doc]}" | grep -qw "$search_term"
        then
            docs_with_term+=("$doc")
        fi
    done

    for doc in "${docs_with_term[@]}"
    do
        echo "$doc" #>&2 #Enter the debug mode if you want to check the output 
    done 
}
##########Calculate Jaccard Index##########

##################Functions for the operations @ and # ##########################
get_most_relevant_stems_for_category() {
    category=$1
    k=$2

    # Create an array to hold the stems and their Jaccard index for the given category
    declare -A ToPrintStems
    ToPrintStems=()  # Ensure that ToPrintStems is re-initialized for each call of the function

    for key in "${!jaccard_index[@]}"
    do
        stem=${key%%_*}  # Extract the stem from the key
        key_category=${key#*_}  # Extract the category from the key
        if [[ $key_category == "$category" ]]
        then
            ToPrintStems["$key"]=${jaccard_index["$key"]}
        fi
    done


    # Sort the keys of ToPrintStems based on their corresponding values in descending order
    IFS=$'\n' read -r -d '' -a sorted_keys < <(printf "%s\0" "${!ToPrintStems[@]}" | while IFS= read -r -d '' key; do echo "${ToPrintStems[$key]} $key"; done | sort -gr | awk '{print $2}' && printf '\0')

    # Print the top k stems
    echo -n "The top $k stems for the Category: $category are: "
    if [ ${#sorted_keys[@]} -eq 0 ]
    then
        echo "No stems for category $category"
    else
        for ((i=0; i<k && i<${#sorted_keys[@]}; i++))
        do
            stem=${sorted_keys[$i]%%_*}  # Extract the stem from the key
            if (( i < k-1 ))
            then
                echo -n "$stem, "
            else
                echo "$stem"
            fi
        done
    fi
}

get_most_relevant_categories_for_stem() {
    stem=$1
    k=$2

    declare -A ToPrintCategories
    ToPrintCategories=()  # Ensure that ToPrintCategories is re-initialized for each call of the function

    for key in "${!jaccard_index[@]}"; do
        if [[ ${key%%_*} == "$stem" ]]; then
            ToPrintCategories["$key"]=${jaccard_index["$key"]}
        fi
    done

    if [ ${#ToPrintCategories[@]} -eq 0 ]; then
        echo "No categories for stem $stem"
        return
    fi

    IFS=$'\n' read -r -d '' -a sorted_keys < <(printf "%s\0" "${!ToPrintCategories[@]}" | while IFS= read -r -d '' key; do echo "${ToPrintCategories[$key]} $key"; done | sort -gr | awk '{print $2}' && printf '\0')

    echo -n "The top $k Categories for the stem: $stem are: "
    for ((i=0; i<k && i<${#sorted_keys[@]}; i++)); do
        category=${sorted_keys[$i]#*_}  # Extract the category from the key
        echo -n "$category"
        if (( i < k-1 )); then
            echo -n ", "
        fi
    done
    echo
}
##################Functions for the operations @ and # ##########################

####################Function for the operation $ ###############################
requested_Jaccard() {
    stem_key=$1
    category_key=$2
    combined_key="${stem_key}_${category_key}"

    if [[ -n ${jaccard_index["$combined_key"]} ]]
    then
        echo "The Jaccard Index for $stem_key and $category_key is: ${jaccard_index["$combined_key"]}"
    else
        echo "The key $combined_key does not exist in the Jaccard Index."
    fi
}
####################Function for the operation $ ###############################

####################Functions for the operations P and C ########################
display_categories() {
    doc_id="$1"
    term_ids="${doc_term["$doc_id"]}"

    # Split the term_ids into an array
    IFS=', ' read -ra term_ids_array <<< "$term_ids"

    echo "The stems associated with the doc are:"

    # Loop through the term_ids and print the corresponding stems
    for term_id in "${term_ids_array[@]}"
    do
        echo "${term_stem["$term_id"]}"
    done
}

fetch_stems() {
    local doc_id="$1"
    local category_values="${doc_category["$doc_id"]}"

    # Split the category_values into an array
    IFS=', ' read -ra category_values_array <<< "$category_values"

    echo "All the associated categories are:"

    # Loop through the category_values and print each one
    for category_value in "${category_values_array[@]}"
    do
        echo "$category_value"
    done
}

count_unique_terms() {
    local doc_id="$1"
    local term_ids="${doc_term["$doc_id"]}"

    # Split the term_ids into an array
    IFS=', ' read -ra term_ids_array <<< "$term_ids"

    # Use associative array to count unique terms
    declare -A unique_terms
    for term_id in "${term_ids_array[@]}"
    do
        unique_terms["$term_id"]=1
    done

    # Print the number of unique terms
    echo "Number of unique terms: ${#unique_terms[@]}"
}

count_unique_categories() {
    local doc_id="$1"
    local category_values="${doc_category["$doc_id"]}"

    # Split the category_values into an array
    IFS=', ' read -ra category_values_array <<< "$category_values"

    # Use associative array to count unique categories
    declare -A unique_categories
    for category_value in "${category_values_array[@]}"
    do
        unique_categories["$category_value"]=1
    done

    # Print the number of unique categories
    echo "Number of unique categories: ${#unique_categories[@]}"
}
####################Functions for the operations P and C ########################


####################A function to display the menu ###############################
print_menu() {  
    echo "Enter the operation you want to perform:"  
    echo "@ <category> <k> : Retrieve and display the <k> most relevant stems (based on Jaccard Index) for a specific category."  
    echo "# <stem> <k> : Display the <k> most relevant categories (based on Jaccard Index) for a specific stem."  
    echo "$ <stem> <category>: Provides the Jaccard Index for a given pair (stem, category)."  
    echo "P <did> -c : Display all the categories associated with the document identified by the code id."  
    echo "P <did> -t : Fetch all the stems present in the document linked to a specific code id."  
    echo "C <did> -c : Calculate and display the count of unique terms within the document specified by the code id."  
    echo "C <did> -t : Calculate and display the count of categories assigned to the document with the code id"  
} 
####################A function to display the menu ###############################

start_program(){
#############This is the main section of the script#############

#Define the paths of the files
file_to_read_categories="C:\Users\mypc1\Desktop\Project_2\Thema_2\FilesForSolution\category_docId.txt"
file_to_read_documents="C:\Users\mypc1\Desktop\Project_2\Thema_2\FilesForSolution\docID_term.txt"
file_to_read_stem_term_pairs="C:\Users\mypc1\Desktop\Project_2\Thema_2\FilesForSolution\stem_term.txt"

#Call the functions to read the files
read_categories_from_file "$file_to_read_categories" categories_doc
read_terms_from_document_file "$file_to_read_documents" doc_term
read_stem_term_pairs "$file_to_read_stem_term_pairs"

#Call the function to populate the doc_category array
populate_doc_category "C:\Users\mypc1\Desktop\Project_2\Thema_2\FilesForSolution\category_docId.txt"

#Call the function to read the stem_term pairs in reverse order
read_stem_term_pairs_helper "$file_to_read_stem_term_pairs"

#Call the function to calculate the Jaccard Index
calculate_jaccard_index

}

main() {
    echo "Welcome to our application"

    while true; do
        print_menu
        read -r operation args
        case $operation in
            @)
                IFS=' ' read -r category k <<< "$args"
                get_most_relevant_stems_for_category "$category" "$k"
                ;;
            '#')
                IFS=' ' read -r stem k <<< "$args"
                get_most_relevant_categories_for_stem "$stem" "$k"
                ;;
            '$')
                IFS=' ' read -r stem category <<< "$args"
                requested_Jaccard "$stem" "$category"
                ;;
            P)
                IFS=' ' read -r did option <<< "$args"
                if [[ $option == "-c" ]]
                then
                    display_categories "$did"
                elif [[ $option == "-t" ]]
                then
                    fetch_stems "$did"
                else
                    echo "Invalid option. Please try again."
                fi
                ;;
            C)
                IFS=' ' read -r did option <<< "$args"
                if [[ $option == "-c" ]]
                then
                    count_unique_terms "$did"
                elif [[ $option == "-t" ]]
                then
                    count_unique_categories "$did"
                else
                    echo "Invalid option. Please try again."
                fi
                ;;
            Q)
                echo "Quitting the program."
                break
                ;;
            *)
                echo "Invalid operation. Please try again."
                ;;
        esac
    done
}

######################### Main program #########################
start_program
main