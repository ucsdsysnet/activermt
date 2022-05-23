#!/bin/bash

make all
for stage in {1..8}
do
    ./cacheWriter.out 10.0.0.2 $stage
    ./cacheReader.out 10.0.0.2
    mv responses.csv responses_$stage.csv
done

echo "experiments complete."