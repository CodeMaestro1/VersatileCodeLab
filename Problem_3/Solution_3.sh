#!/bin/bash

echo "Process started."
echo "Removing old files..."
rm -f sentimentpernewsitem.txt
rm -f stem_term_unix.txt
echo "Old files removed."

# Read positive stems into associative arrays

declare -A positive_stems

echo "Reading positive stems..."
while IFS= read -r line || [[ -n $line ]]
do
    stem=$(echo "$line" | tr -d '[:space:]')
    positive_stems["$stem"]=1
done <mypositive_stems.txt

declare -A negative_stems

echo "Reading negative stems..."

while IFS= read -r line || [[ -n $line ]] 
do

    stem=$(echo "$line" | tr -d '[:space:]')

    negative_stems["$stem"]=1

done <mynegative_stems.txt

# Read stem-term pairs into an associative array
tr -d '\r' < stem_term.txt > stem_term_unix.txt #Remove carriage return characters. 
                                                  #This is necessary because the file was created in Windows.
declare -A stem_term_pairs

while IFS=' ' read -r stem term rest 
do
    if [[ -n $term ]]
    then
        stem_term_pairs["$term"]="$stem"
        #echo "Term: $term, Stem: $stem"
    fi
done <stem_term_unix.txt

#Testing purposes
# Print positive stems
#echo "Positive stems:"
#for stem in "${!positive_stems[@]}" 
#do
#    echo "$stem: ${positive_stems[$stem]}"
#done
#echo "====================================================="
# Print negative stems

#echo "Negative stems:"
#for stem in "${!negative_stems[@]}" 
#do
#    echo "$stem: ${negative_stems[$stem]}"
#done
#echo "====================================================="

# Process each line in the docID_term.txt file
echo "Processing positive and negative stems..."

while IFS= read -r line || [[ -n $line ]] 
do
    # Extract document id
    doc_id=$(echo "$line" | awk '{print $1}')

    # Initialize positive and negative stem counts
    positive_counter=0
    negative_counter=0

    # Process each term in the line
    for term_value in $(echo "$line" | cut -d' ' -f2-)
    do
        # Extract term without value
        term=$(echo "$term_value" | cut -d':' -f1)

        # Check if the term exists in the stem_term_pairs array
        if [[ -v stem_term_pairs["$term"] ]]
        then
            stem=${stem_term_pairs["$term"]}

            # Check if stem is in positive or negative list
            if [[ -v positive_stems["$stem"] ]]
            then
                ((positive_counter++))
            elif [[ -v negative_stems["$stem"] ]]
            then
                ((negative_counter++))
            fi
        fi

        #echo "positive_counter: $positive_counter, negative_counter: $negative_counter" #Test purposes

    done

    # Determine sentiment and write to file
    if ((positive_counter > negative_counter))
    then
        echo "Document $doc_id has a positive sentiment" >>sentimentpernewsitem.txt
    elif ((positive_counter < negative_counter))
    then
        echo "Document $doc_id has a negative sentiment" >>sentimentpernewsitem.txt
    else
        echo "Document $doc_id has a neutral sentiment" >>sentimentpernewsitem.txt
    fi

done <docID_term.txt

echo "Process ended."
