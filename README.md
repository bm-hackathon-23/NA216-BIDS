# NA216-BIDS

Scripts to BIDS-ify the existing NA216 datalad dataset.

These scripts take a fresh datalad installation of the NA216 dataset and create a BIDS layout from the existing data.

The `.sh` script calls the python script as part of it's execution.

The python environment only needs base modules and `pandas version > 2.0`

NOTE: This was manually converted based on available information. Some of the information (especially in the sidecars) will be inaccurate.

Steps:

1. `cd` to a working directory.
2. `datalad install -r https://cau-gin.brainminds.riken.jp/brainminds/MRI-NA216`
3. ./move-to-bids.sh /path/to/working/directory/MRI-NA216
4. Inspect / utilize BIDS dataset.

Ideally, after moving the files the Neurobagel tools will be able to extract / describe the dataset to add it to the graph.

Brent McPherson (c) 2023, ORIGAMI Lab, McGill University

