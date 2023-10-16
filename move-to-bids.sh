#!/bin/bash

## build paths to data
DATADIR=$1

if [ -z "$DATADIR" ]; then
    echo "No path to cloned datalad copy of NA216 dataset passed. Can't do anything."
    exit 1
fi

##
## pull the data needed to parse subject IDs
##

## datalad can't find files unless it's invoked w/in the dataset?
cd $DATADIR
datalad get invivo/i_Individual_List/Individual_information_invivo.xlsx
datalad get invivo/i_Variables_gm
datalad get invivo/i_Label052/Label052_classification.xlsx
datalad get invivo/i_Label111/Label111_classification.xlsx
datalad get exvivo/e_Individual_List/individual_information_exvivo.xlsx
datalad get exvivo/e_Variables_gm
cd -

## make outputs if they don't exist
if [ ! -d $DATADIR/bids ]; then
    echo "Creating BIDS folder..."
    mkdir -p $DATADIR/bids/{rawdata,derivatives}
    mkdir $DATADIR/bids/derivatives/outputs-v1.0.0
    mkdir $DATADIR/bids/derivatives/tabular-v1.0.0
fi

BIDSRAW=$DATADIR/bids/rawdata
BIDSDER=$DATADIR/bids/derivatives/outputs-v1.0.0
BIDSTAB=$DATADIR/bids/derivatives/tabular-v1.0.0

cat <<EOF > $BIDSRAW/README.md
# README Placeholder for NA216 BIDS Dataset

Fill in relevant information here.

EOF

echo '{"Name": "Brain/MINDS Marmoset Brain MRI Dataset NA216 (In Vivo) and eNA91 (Ex Vivo)",
       "BIDSVersion": "1.8.0",
	   "Authors": "Brain/MINDS RIKEN",
	   "Citation": ["https://doi.org/10.24475/bminds.mri.thj.4624"],
	   "Funding": ["Japan Agency for Medical Research and Development (AMED)"],
	   "Ethics": ["Approved"],
	   "DatasetDOI": ["https://doi.org/10.24475/bminds.mri.thj.4624"],
	   "GeneratedBy": "Brent McPherson"}' > $BIDSRAW/dataset_description.json

## create participants.tsv and other BIDS files
python move-to-bids.py $DATADIR

echo "Migrating data into BIDS layout..."
{

    read ## skip header column

    ## for every row in the data frame
    while read file; do

	## awk out the columns as variable for sanity checks
	bidsid=`echo $file | awk '{print $1}'`
	subjid=${bidsid##*-}
	species=`echo $file | awk '{print $2}'`
	age=`echo $file | awk '{print $3}'`
	sex=`echo $file | awk '{print $4}'`
	weight=`echo $file | awk '{print $5}'`
	evdbid=`echo $file | awk '{print $6}'`
	evage=`echo $file | awk '{print $7}'`

	## make the subject folder
	mkdir -p $BIDSRAW/$bidsid/ses-01/{anat,dwi,func}
	
	## "pretty" print the data row
	echo "BIDS: $bidsid | Genus-Species: $species | Age: $age | Sex: $sex | Weight (grams): $weight | Ex-vivo ID: ${evdbid} | Ex-vivo Age: $evage "
	echo "Moving subject: $subjid to BIDS ID: $bidsid ..."
	
	##
	## start moving files
	##
	
	echo " -- Moving any in-vivo scans..."
	
	## move T1
	if [ -L $DATADIR/invivo/i_T1WI/T1WI_$subjid.nii.gz ]; then
	    mv $DATADIR/invivo/i_T1WI/T1WI_$subjid.nii.gz $BIDSRAW/$bidsid/ses-01/anat/${bidsid}_ses-01_acq-invivo_T1w.nii.gz
	fi

	## move T2
	if [ -L $DATADIR/invivo/i_T2WI/T2WI_$subjid.nii.gz ]; then
	    mv $DATADIR/invivo/i_T2WI/T2WI_$subjid.nii.gz $BIDSRAW/$bidsid/ses-01/anat/${bidsid}_ses-01_acq-invivo_T2w.nii.gz
	fi

	## move DWI
	if [ -f $DATADIR/invivo/i_DWI/dwi_$subjid.nii ]; then
	    mv $DATADIR/invivo/i_DWI/dwi_$subjid.nii $BIDSRAW/$bidsid/ses-01/dwi/${bidsid}_ses-01_acq-invivo_dwi.nii
	    cp $DATADIR/invivo/i_DWI_MPG_info/NA216.bval $BIDSRAW/$bidsid/ses-01/dwi/${bidsid}_ses-01_acq-invivo_dwi.bval
	    cp $DATADIR/invivo/i_DWI_MPG_info/NA216.bvec $BIDSRAW/$bidsid/ses-01/dwi/${bidsid}_ses-01_acq-invivo_dwi.bvec
	fi

	## move Aneth fMRI
	if [ -f $DATADIR/invivo/i_fMRI_Aneth_raw/fmri_aneth_raw_$subjid.nii.gz ]; then
	    mv $DATADIR/invivo/i_fMRI_Aneth_raw/fmri_aneth_raw_$subjid.nii.gz $BIDSRAW/$bidsid/ses-01/func/${bidsid}_ses-01_task-aneth_acq-invivo_bold.nii.gz
	fi

	## move Awake fMRI
	if [ -f $DATADIR/invivo/i_fMRI_Awake_raw/fmri_awake_raw_${subjid}_1.nii.gz ]; then
	    mv $DATADIR/invivo/i_fMRI_Awake_raw/fmri_awake_raw_${subjid}_1.nii.gz $BIDSRAW/$bidsid/ses-01/func/${bidsid}_ses-01_task-awake_acq-invivo_run-01_bold.nii.gz
	fi

	if [ -f $DATADIR/invivo/i_fMRI_Awake_raw/fmri_awake_raw_${subjid}_2.nii.gz ]; then
	    mv $DATADIR/invivo/i_fMRI_Awake_raw/fmri_awake_raw_${subjid}_2.nii.gz $BIDSRAW/$bidsid/ses-01/func/${bidsid}_ses-01_task-awake_acq-invivo_run-02_bold.nii.gz
	fi

	if [ -f $DATADIR/invivo/i_fMRI_Awake_raw/fmri_awake_raw_${subjid}_3.nii.gz ]; then
	    mv $DATADIR/invivo/i_fMRI_Awake_raw/fmri_awake_raw_${subjid}_3.nii.gz $BIDSRAW/$bidsid/ses-01/func/${bidsid}_ses-01_task-awake_acq-invivo_run-03_bold.nii.gz
	fi

	echo " -- Moving any ex-vivo scans..."

	## move T2 w/o exvivo data
	if [ -L $DATADIR/exvivo/e_T2WI/T2WI_${evdbid}.nii.gz ]; then
	    mv $DATADIR/exvivo/e_T2WI/T2WI_${evdbid}.nii.gz $BIDSRAW/$bidsid/ses-01/anat/${bidsid}_ses-01_acq-exvivo_T2w.nii.gz
	fi

	## move T2 w/ exvivo data w/ invivo id
	if [ -L $DATADIR/exvivo/e_T2WI/T2WI_${evdbid}_i${subjid}.nii.gz ]; then
	    mv $DATADIR/exvivo/e_T2WI/T2WI_${evdbid}_i$subjid.nii.gz $BIDSRAW/$bidsid/ses-01/anat/${bidsid}_ses-01_acq-exvivo_T2w.nii.gz
	fi

	## move T2 w/ ex-vivo data w/ typo in invivo id
	if [ -L $DATADIR/exvivo/e_T2WI/T2WI_${evdbid}i${subjid}.nii.gz ]; then
	    mv $DATADIR/exvivo/e_T2WI/T2WI_${evdbid}i$subjid.nii.gz $BIDSRAW/$bidsid/ses-01/anat/${bidsid}_ses-01_acq-exvivo_T2w.nii.gz
	fi

	## move dwi w/o invivo data
	if [ -f $DATADIR/exvivo/e_DWI/dwi_${evdbid}.nii.gz ]; then
	    mv $DATADIR/exvivo/e_DWI/dwi_${evdbid}.nii.gz $BIDSRAW/$bidsid/ses-01/dwi/${bidsid}_ses-01_acq-exvivo_dwi.nii.gz
	    mv $DATADIR/exvivo/e_DWI_MPG_info/${evdbid}.bval $BIDSRAW/$bidsid/ses-01/dwi/${bidsid}_ses-01_acq-exvivo_dwi.bval
	    mv $DATADIR/exvivo/e_DWI_MPG_info/${evdbid}.bvec $BIDSRAW/$bidsid/ses-01/dwi/${bidsid}_ses-01_acq-exvivo_dwi.bvec
	fi

	## move dwi w/ in-vivo data
	if [ -f $DATADIR/exvivo/e_DWI/dwi_${evdbid}_i${subjid}.nii.gz ]; then
	    mv $DATADIR/exvivo/e_DWI/dwi_${evdbid}_i$subjid.nii.gz $BIDSRAW/$bidsid/ses-01/dwi/${bidsid}_ses-01_acq-exvivo_dwi.nii.gz
	    mv $DATADIR/exvivo/e_DWI_MPG_info/${evdbid}_i${subjid}.bval $BIDSRAW/$bidsid/ses-01/dwi/${bidsid}_ses-01_acq-exvivo_dwi.bval
	    mv $DATADIR/exvivo/e_DWI_MPG_info/${evdbid}_i${subjid}.bvec $BIDSRAW/$bidsid/ses-01/dwi/${bidsid}_ses-01_acq-exvivo_dwi.bvec
	fi

	echo " -- Moving any derived data..."

	## make the subject folder
	mkdir -p $BIDSDER/$bidsid/ses-01/{anat,dwi,func,xfm}

	## move anaesthtized functional networks
	if [ -L $DATADIR/invivo/i_AnethFC/AnethFC_$subjid.csv ]; then
	    mv $DATADIR/invivo/i_AnethFC/AnethFC_$subjid.csv $BIDSDER/$bidsid/ses-01/func/${bidsid}_ses-01_task-aneth_acq-invivo_atlas-Label052_conmat.csv
	fi

	## move awake functional networks
	if [ -L $DATADIR/invivo/i_AwakeFC/AwakeFC_$subjid.csv ]; then
	    mv $DATADIR/invivo/i_AwakeFC/AwakeFC_$subjid.csv $BIDSDER/$bidsid/ses-01/func/${bidsid}_ses-01_task-awake_acq-invivo_atlas-Label052_conmat.csv
	fi

	## move diffusion structural networks
	if [ -L $DATADIR/invivo/i_DiffusionSC/DiffusionSC_$subjid.csv ]; then
	    mv $DATADIR/invivo/i_DiffusionSC/DiffusionSC_$subjid.csv $BIDSDER/$bidsid/ses-01/dwi/${bidsid}_ses-01_acq-invivo_atlas-Label052_desc-dwi_conmat.csv
	fi

	## move T1/T2 ratio images
	if [ -L $DATADIR/invivo/i_T1wT2w/T1wT2w_$subjid.nii.gz ]; then
	    mv $DATADIR/invivo/i_T1wT2w/T1wT2w_$subjid.nii.gz $BIDSDER/$bidsid/ses-01/anat/${bidsid}_ses-01_acq-invivo_desc-T1T2ratio_map.nii.gz
	fi

	## move labels006
	if [ -L $DATADIR/invivo/i_Label006/Label006_$subjid.nii.gz ]; then
	    mv $DATADIR/invivo/i_Label006/Label006_$subjid.nii.gz $BIDSDER/$bidsid/ses-01/anat/${bidsid}_ses-01_acq-invivo_atlas-Label006_dseg.nii.gz
	fi

	## move labels052
	if [ -L $DATADIR/invivo/i_Label052/Label052_$subjid.nii.gz ]; then
	    mv $DATADIR/invivo/i_Label052/Label052_$subjid.nii.gz $BIDSDER/$bidsid/ses-01/anat/${bidsid}_ses-01_acq-invivo_atlas-Label052_dseg.nii.gz
	fi

	## move labels111
	if [ -L $DATADIR/invivo/i_Label111/Label111_$subjid.nii.gz ]; then
	    mv $DATADIR/invivo/i_Label111/Label111_$subjid.nii.gz $BIDSDER/$bidsid/ses-01/anat/${bidsid}_ses-01_acq-invivo_atlas-Label111_dseg.nii.gz
	fi

	## move FA image
	if [ -L $DATADIR/invivo/i_DTI_FA/dtiFA_$subjid.nii.gz ]; then
	    mv $DATADIR/invivo/i_DTI_FA/dtiFA_$subjid.nii.gz $BIDSDER/$bidsid/ses-01/dwi/${bidsid}_ses-01_acq-invivo_model-tensor_desc-FA_mdp.nii.gz
	fi

	## move FAc image
	if [ -L $DATADIR/invivo/i_DTI_FAc/dtiFAc_$subjid.nii.gz ]; then
	    mv $DATADIR/invivo/i_DTI_FAc/dtiFAc_$subjid.nii.gz $BIDSDER/$bidsid/ses-01/dwi/${bidsid}_ses-01_acq-invivo_model-tensor_desc-FAc_mdp.nii.gz
	fi

	## move MD image
	if [ -L $DATADIR/invivo/i_DTI_MD/dtiMD_$subjid.nii.gz ]; then
	    mv $DATADIR/invivo/i_DTI_MD/dtiMD_$subjid.nii.gz $BIDSDER/$bidsid/ses-01/dwi/${bidsid}_ses-01_acq-invivo_model-tensor_desc-MD_mdp.nii.gz
	fi

	## move AD image
	if [ -L $DATADIR/invivo/i_DTI_AD/dtiAD_$subjid.nii.gz ]; then
	    mv $DATADIR/invivo/i_DTI_AD/dtiAD_$subjid.nii.gz $BIDSDER/$bidsid/ses-01/dwi/${bidsid}_ses-01_acq-invivo_model-tensor_desc-AD_mdp.nii.gz
	fi

	## move RD image
	if [ -L $DATADIR/invivo/i_DTI_RD/dtiRD_$subjid.nii.gz ]; then
	    mv $DATADIR/invivo/i_DTI_RD/dtiRD_$subjid.nii.gz $BIDSDER/$bidsid/ses-01/dwi/${bidsid}_ses-01_acq-invivo_model-tensor_desc-RD_mdp.nii.gz
	fi

	## move small tck 
	if [ -f $DATADIR/invivo/i_DWI_TCK/${subjid}_100T.tck ]; then
	    mv $DATADIR/invivo/i_DWI_TCK/${subjid}_100T.tck $BIDSDER/$bidsid/ses-01/dwi/${bidsid}_ses-01_acq-invivo_model-tensor_desc-subset_tracks.tck
	fi

	## move full tck 
	if [ -f $DATADIR/invivo/i_DWI_TCK_full/${subjid}_003Ms.tck.zip ]; then
	    mv $DATADIR/invivo/i_DWI_TCK_full/${subjid}_003Ms.tck.zip $BIDSDER/$bidsid/ses-01/dwi/${bidsid}_ses-01_acq-invivo_model-tensor_desc-full_tracks.tck.zip
	fi

	##
	## exvivo derivatives
	##
	
	## move ev dti ad
	if [ -L $DATADIR/exvivo/e_DTI_AD/dtiAD_${evdbid}.nii.gz ]; then
	    mv $DATADIR/exvivo/e_DTI_AD/dtiAD_${evdbid}.nii.gz $BIDSDER/$bidsid/ses-01/dwi/${bidsid}_ses-01_acq-exvivo_model-tensor_desc-AD_mdp.nii.gz
	fi
	## move ev dti ad
	if [ -L $DATADIR/exvivo/e_DTI_AD/dtiAD_${evdbid}_i${subjid}.nii.gz ]; then
	    mv $DATADIR/exvivo/e_DTI_AD/dtiAD_${evdbid}_i$subjid.nii.gz $BIDSDER/$bidsid/ses-01/dwi/${bidsid}_ses-01_acq-exvivo_model-tensor_desc-AD_mdp.nii.gz
	fi
	
	## move ev dti fa
	if [ -L $DATADIR/exvivo/e_DTI_FA/dtiFA_${evdbid}.nii.gz ]; then
	    mv $DATADIR/exvivo/e_DTI_FA/dtiFA_${evdbid}.nii.gz $BIDSDER/$bidsid/ses-01/dwi/${bidsid}_ses-01_acq-exvivo_model-tensor_desc-FA_mdp.nii.gz
	fi
	## move ev dti fa
	if [ -L $DATADIR/exvivo/e_DTI_FA/dtiFA_${evdbid}_i${subjid}.nii.gz ]; then
	    mv $DATADIR/exvivo/e_DTI_FA/dtiFA_${evdbid}_i$subjid.nii.gz $BIDSDER/$bidsid/ses-01/dwi/${bidsid}_ses-01_acq-exvivo_model-tensor_desc-FA_mdp.nii.gz
	fi
	  
	## move ev dti fac
	if [ -L $DATADIR/exvivo/e_DTI_FAc/dtiFAc_${evdbid}.nii.gz ]; then
	    mv $DATADIR/exvivo/e_DTI_FAc/dtiFAc_${evdbid}.nii.gz $BIDSDER/$bidsid/ses-01/dwi/${bidsid}_ses-01_acq-exvivo_model-tensor_desc-FAc_mdp.nii.gz
	fi
	## move ev dti fac
	if [ -L $DATADIR/exvivo/e_DTI_FAc/dtiFAc_${evdbid}_i${subjid}.nii.gz ]; then
	    mv $DATADIR/exvivo/e_DTI_FAc/dtiFAc_${evdbid}_i$subjid.nii.gz $BIDSDER/$bidsid/ses-01/dwi/${bidsid}_ses-01_acq-exvivo_model-tensor_desc-FAc_mdp.nii.gz
	fi

	## move ev dti md
	if [ -L $DATADIR/exvivo/e_DTI_MD/dtiMD_${evdbid}.nii.gz ]; then
	    mv $DATADIR/exvivo/e_DTI_MD/dtiMD_${evdbid}.nii.gz $BIDSRAW/$bidsid/ses-01/dwi/${bidsid}_ses-01_acq-exvivo_model-tensor_desc-MD_mdp.nii.gz
	fi
	## move ev dti md
	if [ -L $DATADIR/exvivo/e_DTI_MD/dtiMD_${evdbid}_i${subjid}.nii.gz ]; then
	    mv $DATADIR/exvivo/e_DTI_MD/dtiMD_${evdbid}_i$subjid.nii.gz $BIDSDER/$bidsid/ses-01/dwi/${bidsid}_ses-01_acq-exvivo_model-tensor_desc-MD_mdp.nii.gz
	fi

	## move ev dti rd
	if [ -L $DATADIR/exvivo/e_DTI_RD/dtiRD_${evdbid}.nii.gz ]; then
	    mv $DATADIR/exvivo/e_DTI_RD/dtiRD_${evdbid}.nii.gz $BIDSDER/$bidsid/ses-01/dwi/${bidsid}_ses-01_acq-exvivo_model-tensor_desc-RD_mdp.nii.gz
	fi
	## move ev dti rd
	if [ -L $DATADIR/exvivo/e_DTI_RD/dtiRD_${evdbid}_i${subjid}.nii.gz ]; then
	    mv $DATADIR/exvivo/e_DTI_RD/dtiRD_${evdbid}_i$subjid.nii.gz $BIDSDER/$bidsid/ses-01/dwi/${bidsid}_ses-01_acq-exvivo_model-tensor_desc-RD_mdp.nii.gz
	fi

	## move label052
	if [ -L $DATADIR/exvivo/e_Label052/Label052_${evdbid}.nii.gz ]; then
	    mv $DATADIR/exvivo/e_Label052/Label052_${evdbid}.nii.gz $BIDSDER/$bidsid/ses-01/dwi/${bidsid}_ses-01_acq-exvivo_atlas-Label052_dseg.nii.gz
	fi
	## move label052 w/ ivvivo id
	if [ -L $DATADIR/exvivo/e_Label052/Label052_${evdbid}_i${subjid}.nii.gz ]; then
	    mv $DATADIR/exvivo/e_Label052/Label052_${evdbid}_i$subjid.nii.gz $BIDSDER/$bidsid/ses-01/dwi/${bidsid}_ses-01_acq-exvivo_atlas-Label052_dseg.nii.gz
	fi

	## move ex dwi b1000
	if [ -L $DATADIR/exvivo/e_DiffusionSC/DiffusionSC_b1000/DiffusionSC_b1000_${evdbid}.csv ]; then
	    mv $DATADIR/exvivo/e_DiffusionSC/DiffusionSC_b1000/DiffusionSC_b1000_${evdbid}.csv $BIDSDER/$bidsid/ses-01/dwi/${bidsid}_ses-01_acq-exvivo_atlas-Label052_desc-b1000_conmat.csv
	fi
	## move ex dwi b1000
	if [ -L $DATADIR/exvivo/e_DiffusionSC/DiffusionSC_b1000/DiffusionSC_b1000_${evdbid}_i${subjid}.csv ]; then
	    mv $DATADIR/exvivo/e_DiffusionSC/DiffusionSC_b1000/DiffusionSC_b1000_${evdbid}_i$subjid.csv $BIDSDER/$bidsid/ses-01/dwi/${bidsid}_ses-01_acq-exvivo_atlas-Label052_desc-b1000_conmat.csv
	fi

	## move ex dwi b3000
	if [ -L $DATADIR/exvivo/e_DiffusionSC/DiffusionSC_b3000/DiffusionSC_b3000_${evdbid}.csv ]; then
	    mv $DATADIR/exvivo/e_DiffusionSC/DiffusionSC_b3000/DiffusionSC_b3000_${evdbid}.csv $BIDSDER/$bidsid/ses-01/dwi/${bidsid}_ses-01_acq-exvivo_atlas-Label052_desc-b3000_conmat.csv
	fi
	## move ex dwi b3000
	if [ -L $DATADIR/exvivo/e_DiffusionSC/DiffusionSC_b3000/DiffusionSC_b3000_${evdbid}_i${subjid}.csv ]; then
	    mv $DATADIR/exvivo/e_DiffusionSC/DiffusionSC_b3000/DiffusionSC_b3000_${evdbid}_i$subjid.csv $BIDSDER/$bidsid/ses-01/dwi/${bidsid}_ses-01_acq-exvivo_atlas-Label052_desc-b3000_conmat.csv
	fi

	## move ex dwi 5000
	if [ -L $DATADIR/exvivo/e_DiffusionSC/DiffusionSC_b5000/DiffusionSC_b5000_${evdbid}.csv ]; then
	    mv $DATADIR/exvivo/e_DiffusionSC/DiffusionSC_b5000/DiffusionSC_b5000_${evdbid}.csv $BIDSDER/$bidsid/ses-01/dwi/${bidsid}_ses-01_acq-exvivo_atlas-Label052_desc-b5000_conmat.csv
	fi
	## move ex dwi 5000
	if [ -L $DATADIR/exvivo/e_DiffusionSC/DiffusionSC_b5000/DiffusionSC_b5000_${evdbid}_i${subjid}.csv ]; then
	    mv $DATADIR/exvivo/e_DiffusionSC/DiffusionSC_b5000/DiffusionSC_b5000_${evdbid}_i$subjid.csv $BIDSDER/$bidsid/ses-01/dwi/${bidsid}_ses-01_acq-exvivo_atlas-Label052_desc-b5000_conmat.csv
	fi

	##
	## move the xfm files
	##

	## are these subj-2-template?
	
	## diffusion invivo transorms
	if [ -f $DATADIR/invivo/i_deformable_info/i_DWI_deformable/T_i_dwi_${subjid}_0GenericAffine.mat ]; then
	    mv $DATADIR/invivo/i_deformable_info/i_DWI_deformable/T_i_dwi_${subjid}_0GenericAffine.mat $BIDSDER/$bidsid/ses-01/xfm/${bidsid}_ses-01_acq-invivo_from-dwi_to-NA216_mode-image_Affine.mat
	    mv $DATADIR/invivo/i_deformable_info/i_DWI_deformable/T_i_dwi_${subjid}_Warp.nii.gz $BIDSDER/$bidsid/ses-01/xfm/${bidsid}_ses-01_acq-invivo_from-dwi_to-NA216_mode-image_Warp.nii.gz
	    mv $DATADIR/invivo/i_deformable_info/i_DWI_deformable/T_i_dwi_${subjid}_InverseWarp.nii.gz $BIDSDER/$bidsid/ses-01/xfm/${bidsid}_ses-01_acq-invivo_from-dwi_to-NA216_mode-image_InverseWarp.nii.gz
	fi

	## diffusion exvivo transorms
	if [ -f $DATADIR/exvivo/e_deformable_info/e_DWI_deformable/T_dwi_${evdbid}_Affine.txt ]; then
	    mv $DATADIR/exvivo/e_deformable_info/e_DWI_deformable/T_dwi_${evdbid}_Affine.txt $BIDSDER/$bidsid/ses-01/xfm/${bidsid}_ses-01_acq-exvivo_from-dwi_to-NA216_mode-image_Affine.txt
	    mv $DATADIR/exvivo/e_deformable_info/e_DWI_deformable/T_dwi_${evdbid}_Warp.nii.gz $BIDSDER/$bidsid/ses-01/xfm/${bidsid}_ses-01_acq-exvivo_from-dwi_to-NA216_mode-image_Warp.nii.gz
	    mv $DATADIR/exvivo/e_deformable_info/e_DWI_deformable/T_dwi_${evdbid}_InverseWarp.nii.gz $BIDSDER/$bidsid/ses-01/xfm/${bidsid}_ses-01_acq-exvivo_from-dwi_to-NA216_mode-image_InverseWarp.nii.gz
	fi
	if [ -f $DATADIR/exvivo/e_deformable_info/e_DWI_deformable/T_dwi_${evdbid}_i${subjid}_Affine.txt ]; then
	    mv $DATADIR/exvivo/e_deformable_info/e_DWI_deformable/T_dwi_${evdbid}_i${subjid}_Affine.txt $BIDSDER/$bidsid/ses-01/xfm/${bidsid}_ses-01_acq-exvivo_from-dwi_to-NA216_mode-image_Affine.txt
	    mv $DATADIR/exvivo/e_deformable_info/e_DWI_deformable/T_dwi_${evdbid}_i${subjid}_Warp.nii.gz $BIDSDER/$bidsid/ses-01/xfm/${bidsid}_ses-01_acq-exvivo_from-dwi_to-NA216_mode-image_Warp.nii.gz
	    mv $DATADIR/exvivo/e_deformable_info/e_DWI_deformable/T_dwi_${evdbid}_i${subjid}_InverseWarp.nii.gz $BIDSDER/$bidsid/ses-01/xfm/${bidsid}_ses-01_acq-exvivo_from-dwi_to-NA216_mode-image_InverseWarp.nii.gz
	fi

	## T1 transforms
	if [ -f $DATADIR/invivo/i_deformable_info/i_T1_deformable/T_T1WI_${subjid}_0GenericAffine.mat ]; then
	    mv $DATADIR/invivo/i_deformable_info/i_T1_deformable/T_T1WI_${subjid}_0GenericAffine.mat $BIDSDER/$bidsid/ses-01/xfm/${bidsid}_ses-01_acq-invivo_from-T1w_to-NA216_mode-image_Affine.mat
	    mv $DATADIR/invivo/i_deformable_info/i_T1_deformable/T_T1WI_${subjid}_Warp.nii.gz $BIDSDER/$bidsid/ses-01/xfm/${bidsid}_ses-01_acq-invivo_from-T1w_to-NA216_mode-image_Warp.nii.gz
	    mv $DATADIR/invivo/i_deformable_info/i_T1_deformable/T_T1WI_${subjid}_InverseWarp.nii.gz $BIDSDER/$bidsid/ses-01/xfm/${bidsid}_ses-01_acq-invivo_from-T1w_to-NA216_mode-image_InverseWarp.nii.gz
	fi

	## T2 transforms
	if [ -f $DATADIR/invivo/i_deformable_info/i_T2_deformable/T_T2WI_${subjid}_0GenericAffine.mat ]; then
	    mv $DATADIR/invivo/i_deformable_info/i_T2_deformable/T_T2WI_${subjid}_0GenericAffine.mat $BIDSDER/$bidsid/ses-01/xfm/${bidsid}_ses-01_acq-invivo_from-T2w_to-NA216_mode-image_Affine.mat
	    mv $DATADIR/invivo/i_deformable_info/i_T2_deformable/T_T2WI_${subjid}_Warp.nii.gz $BIDSDER/$bidsid/ses-01/xfm/${bidsid}_ses-01_acq-invivo_from-T2w_to-NA216_mode-image_Warp.nii.gz
	    mv $DATADIR/invivo/i_deformable_info/i_T2_deformable/T_T2WI_${subjid}_InverseWarp.nii.gz $BIDSDER/$bidsid/ses-01/xfm/${bidsid}_ses-01_acq-invivo_from-T2w_to-NA216_mode-image_InverseWarp.nii.gz
	fi
	
	## move fucntional after resampling (aneth) 
	if [ -f $DATADIR/invivo/i_deformable_info/i_fMRI_Aneth_deformed/fmri_aneth_deformed_${subjid}.nii.gz ]; then
	    mv $DATADIR/invivo/i_deformable_info/i_fMRI_Aneth_deformed/fmri_aneth_deformed_${subjid}.nii.gz $BIDSDER/$bidsid/ses-01/func/${bidsid}_ses-01_space-NA216_task-aneth_desc-aligned_bold.nii.gz
	fi

	## move awake data
	if [ -f $DATADIR/invivo/i_deformable_info/i_fMRI_Awake_deformed/fmri_awake_deformed_${subjid}_1.nii.gz ]; then
	    mv $DATADIR/invivo/i_deformable_info/i_fMRI_Awake_deformed/fmri_awake_deformed_${subjid}_1.nii.gz $BIDSDER/$bidsid/ses-01/func/${bidsid}_ses-01_space-NA216_task-awake_desc-aligned_run-01_bold.nii.gz
	fi
	if [ -f $DATADIR/invivo/i_deformable_info/i_fMRI_Awake_deformed/fmri_awake_deformed_${subjid}_2.nii.gz ]; then
	    mv $DATADIR/invivo/i_deformable_info/i_fMRI_Awake_deformed/fmri_awake_deformed_${subjid}_2.nii.gz $BIDSDER/$bidsid/ses-01/func/${bidsid}_ses-01_space-NA216_task-awake_desc-aligned_run-02_bold.nii.gz
	fi
	if [ -f $DATADIR/invivo/i_deformable_info/i_fMRI_Awake_deformed/fmri_awake_deformed_${subjid}_3.nii.gz ]; then
	    mv $DATADIR/invivo/i_deformable_info/i_fMRI_Awake_deformed/fmri_awake_deformed_${subjid}_3.nii.gz $BIDSDER/$bidsid/ses-01/func/${bidsid}_ses-01_space-NA216_task-awake_desc-aligned_run-03_bold.nii.gz
	fi

	##
	## clean out empty folders
	##
	
	if [ -z "$(ls -A $BIDSRAW/$bidsid/ses-01/anat)" ]; then
	    rmdir $BIDSRAW/$bidsid/ses-01/anat
	fi
	if [ -z "$(ls -A $BIDSRAW/$bidsid/ses-01/dwi)" ]; then
	    rmdir $BIDSRAW/$bidsid/ses-01/dwi
	fi
	if [ -z "$(ls -A $BIDSRAW/$bidsid/ses-01/func)" ]; then
	    rmdir $BIDSRAW/$bidsid/ses-01/func
	fi
	if [ -z "$(ls -A $BIDSRAW/$bidsid/ses-01)" ]; then
	    rmdir $BIDSRAW/$bidsid/ses-01
	fi
	if [ -z "$(ls -A $BIDSRAW/$bidsid)" ]; then
	    rmdir $BIDSRAW/$bidsid
	fi

	if [ -z "$(ls -A $BIDSDER/$bidsid/ses-01/anat)" ]; then
	    rmdir $BIDSDER/$bidsid/ses-01/anat
	fi
	if [ -z "$(ls -A $BIDSDER/$bidsid/ses-01/dwi)" ]; then
	    rmdir $BIDSDER/$bidsid/ses-01/dwi
	fi
	if [ -z "$(ls -A $BIDSDER/$bidsid/ses-01/func)" ]; then
	    rmdir $BIDSDER/$bidsid/ses-01/func
	fi
	if [ -z "$(ls -A $BIDSDER/$bidsid/ses-01/xfm)" ]; then
	    rmdir $BIDSDER/$bidsid/ses-01/xfm
	fi
	if [ -z "$(ls -A $BIDSDER/$bidsid/ses-01)" ]; then
	    rmdir $BIDSDER/$bidsid/ses-01
	fi
	if [ -z "$(ls -A $BIDSDER/$bidsid)" ]; then
	    rmdir $BIDSDER/$bidsid
	fi

    done
    
}<${BIDSRAW}/participants.tsv

## make top level sidecars to reduce redundant filler
##  -- This should be rextracted / may require sub-###-ses-01 variability to capture unique info

echo '{"Manufacturer": "Bruker","ManufacturersModelName": "BioSpec","ImageType": ["ORIGINAL", "PRIMARY", "M", "ND", "NORM"],"AcquisitionTime": 1200,"AcquisitionDate": 20230826,"MagneticFieldStrength": 9.4,"FlipAngle": 12,"EchoTime": 0.002,"InversionTime": 1.600,"NumberOfAverages": 1,"RepetitionTime": 6.000,"AcquisitionVoxelSize": [270, 270, 540]}' > $BIDSRAW/ses-01_acq-invivo_T1w.json

echo '{"Manufacturer": "Bruker","ManufacturersModelName": "BioSpec","ImageType": ["ORIGINAL", "PRIMARY", "M", "ND", "NORM"],"AcquisitionTime": 444,"AcquisitionDate": 20230826,"MagneticFieldStrength": 9.4,"FlipAngle": 90,"RepetitionTime": 4.000,"EchoTime": 0.022,"RAREFactor": 4,"Numberof Averages": 1,"AcquisitionVoxelSize": [270, 270, 540]}' > $BIDSRAW/ses-01_acq-invivo_T2w.json

echo '{"Manufacturer": "Bruker","ManufacturersModelName": "BioSpec","ImageType": ["ORIGINAL","PRIMARY", "M", "ND", "NORM"],"AcquisitionTime": 3000,"AcquisitionDate": 20230826,"MagneticFieldStrength": 9.4,"FlipAngle": 90,"RepetitionTime": 3.000,"EchoTime": 0.0256,"PhaseEncodingDirection": "i-","AcquisitionVoxelSize": [350, 350, 700]}' > $BIDSRAW/ses-01_acq-invivo_dwi.json

echo '{"Manufacturer": "Bruker","ManufacturersModelName": "BioSpec","ImageType": ["ORIGINAL", "PRIMARY", "M", "ND", "NORM"],"AcquisitionTime": 1500,"AcquisitionDate": 20230826,"MagneticFieldStrength": 9.4,"FlipAngle": 40,"EchoTime": 0.018,"NumberOfAverage": 1,"RepetitionTime": 2.000,"AcquisitionVoxelSize": [500, 500, 1000]}' > $BIDSRAW/ses-01_task-aneth_acq-invivo_bold.json

echo '{"Manufacturer": "Bruker","ManufacturersModelName": "BioSpec","ImageType": ["ORIGINAL", "PRIMARY", "M", "ND", "NORM"],"AcquisitionTime": 1324.1324,"AcquisitionDate": 20230826,"MagneticFieldStrength": 9.4,"FlipAngle": 8,"EchoTime": 0.018,"RepetitionTime": 2,"AcquisitionVoxelSize": [500, 500, 1000]}' > $BIDSRAW/ses-01_task-awake_acq-invivo_run-01_bold.json

echo '{"Manufacturer": "Bruker","ManufacturersModelName": "BioSpec","ImageType": ["ORIGINAL", "PRIMARY", "M", "ND", "NORM"],"AcquisitionTime": 1324.1324,"AcquisitionDate": 20230826,"MagneticFieldStrength": 9.4,"FlipAngle": 8,"EchoTime": 0.018,"RepetitionTime": 2,"AcquisitionVoxelSize": [500, 500, 1000]}' > $BIDSRAW/ses-01_task-awake_acq-invivo_run-02_bold.json

echo '{"Manufacturer": "Bruker","ManufacturersModelName": "BioSpec","ImageType": ["ORIGINAL", "PRIMARY", "M", "ND", "NORM"],"AcquisitionTime": 1324.1324,"AcquisitionDate": 20230826,"MagneticFieldStrength": 9.4,"FlipAngle": 8,"EchoTime": 0.018,"RepetitionTime": 2,"AcquisitionVoxelSize": [500, 500, 1000]}' > $BIDSRAW/ses-01_task-awake_acq-invivo_run-03_bold.json

echo '{"Manufacturer": "Bruker","ManufacturersModelName": "BioSpec","ImageType": ["ORIGINAL", "PRIMARY", "M", "ND", "NORM"],"AcquisitionTime": 13800,"AcquisitionDate": 20230826,"MagneticFieldStrength": 9.4,"FlipAngle": 90,"RepetitionTime": 10.000,"EchoTime": 0.0293,"PhaseEncodingDirection": "i-","NumberOfAverages": 16,"AcquisitionVoxelSize": [100, 100, 200]}' > $BIDSRAW/ses-01_acq-exvivo_T2w.json

echo '{"Manufacturer": "Bruker","ManufacturersModelName": "BioSpec","ImageType": ["ORIGINAL", "PRIMARY", "M", "ND", "NORM"],"AcquisitionTime": 23940,"AcquisitionDate": 20230826,"MagneticFieldStrength": 9.4,"FlipAngle": 90,"EchoTime": 0.0284,"RepetitionTime": 4.000,"PhaseEncodingDirection": "i-","NumberOfAverages": 2,"AcquisitionVoxelSize": [200, 200, 200]}' > $BIDSRAW/ses-01_acq-exvivo_dwi.json

## .json sidecars are technically optional for derivatives. They'd be good to add, but currently are mostly BEP proposals.
## So there is no final consensus on what they should be / how they should be structured.

## move the average files to a derivative folder
mkdir -p $BIDSDER/sub-average/ses-01/{anat,dwi}

mv $DATADIR/invivo/i_Average/Average_dtiAD.nii.gz $BIDSDER/sub-average/ses-01/dwi/sub-average_ses-01_acq-invivo_space-NA216_model-tensor_desc-AD_mdp.nii.gz
mv $DATADIR/invivo/i_Average/Average_dtiFA.nii.gz $BIDSDER/sub-average/ses-01/dwi/sub-average_ses-01_acq-invivo_space-NA216_model-tensor_desc-FA_mdp.nii.gz
mv $DATADIR/invivo/i_Average/Average_dtiMD.nii.gz $BIDSDER/sub-average/ses-01/dwi/sub-average_ses-01_acq-invivo_space-NA216_model-tensor_desc-MD_mdp.nii.gz
mv $DATADIR/invivo/i_Average/Average_dtiRD.nii.gz $BIDSDER/sub-average/ses-01/dwi/sub-average_ses-01_acq-invivo_space-NA216_model-tensor_desc-RD_mdp.nii.gz
mv $DATADIR/invivo/i_Average/Average_Label006.nii.gz $BIDSDER/sub-average/ses-01/anat/sub-average_ses-01_acq-invivo_space-NA216_atlas-Label006_dseg.nii.gz
mv $DATADIR/invivo/i_Average/Average_Label052.nii.gz $BIDSDER/sub-average/ses-01/anat/sub-average_ses-01_acq-invivo_space-NA216_atlas-Label052_dseg.nii.gz
mv $DATADIR/invivo/i_Average/Average_Label111.nii.gz $BIDSDER/sub-average/ses-01/anat/sub-average_ses-01_acq-invivo_space-NA216_atlas-Label111_dseg.nii.gz
mv $DATADIR/invivo/i_Average/Average_T1WI.nii.gz $BIDSDER/sub-average/ses-01/anat/sub-average_ses-01_acq-invivo_space-NA216_T1w.nii.gz
mv $DATADIR/invivo/i_Average/Average_T1wT2w.nii.gz $BIDSDER/sub-average/ses-01/anat/sub-average_ses-01_acq-invivo_space-NA216_desc-T1T2ratio_map.nii.gz
mv $DATADIR/invivo/i_Average/Average_T2WI.nii.gz $BIDSDER/sub-average/ses-01/anat/sub-average_ses-01_acq-invivo_space-NA216_T2w.nii.gz

mv $DATADIR/exvivo/e_Average/Average_dtiAD.nii.gz $BIDSDER/sub-average/ses-01/dwi/sub-average_ses-01_acq-exvivo_space-NA216_model-tensor_desc-AD_mdp.nii.gz
mv $DATADIR/exvivo/e_Average/Average_dtiFA.nii.gz $BIDSDER/sub-average/ses-01/dwi/sub-average_ses-01_acq-exvivo_space-NA216_model-tensor_desc-FA_mdp.nii.gz
mv $DATADIR/exvivo/e_Average/Average_dtiMD.nii.gz $BIDSDER/sub-average/ses-01/dwi/sub-average_ses-01_acq-exvivo_space-NA216_model-tensor_desc-MD_mdp.nii.gz
mv $DATADIR/exvivo/e_Average/Average_dtiRD.nii.gz $BIDSDER/sub-average/ses-01/dwi/sub-average_ses-01_acq-exvivo_space-NA216_model-tensor_desc-RD_mdp.nii.gz
mv $DATADIR/exvivo/e_Average/Average_Label052.nii.gz $BIDSDER/sub-average/ses-01/anat/sub-average_ses-01_acq-exvivo_space-NA216_atlas-Label052_dseg.nii.gz
mv $DATADIR/exvivo/e_Average/Average_HRT2WI.nii.gz $BIDSDER/sub-average/ses-01/anat/sub-average_ses-01_acq-exvivo_space-NA216_T2w.nii.gz

