
import os
from pathlib import Path
import shutil
import json

import sys

import numpy as np
import pandas as pd
#import csv

##
## get paths to data
##

#datadir='/home/bcmcpher/Projects/mb-hackathon/changes/MRI-NA216'
datadir = sys.argv[1]

bidsraw = Path(datadir, 'bids', 'rawdata')
bidsder = Path(datadir, 'bids', 'derivatives')

## read the input information for the dataset to know what subjects / directories to make
invivo_dat = pd.read_excel(Path(datadir, 'invivo', 'i_Individual_List', 'Individual_information_invivo.xlsx'), header=0)
exvivo_dat = pd.read_excel(Path(datadir, 'exvivo', 'e_Individual_List', 'individual_information_exvivo.xlsx'), header=0)

partout = Path(bidsraw, 'participants.tsv')
partjson_out = Path(bidsraw, "participants.json")

invivo = Path(datadir, 'invivo', 'i_Variables_gm').glob('*.xlsx')
ix1 = pd.read_excel(Path(datadir, 'invivo', 'i_Variables_gm', 'Brain_001_summary.xlsx'), sheet_name='T1&2w contrasts (all)') 
ix2 = pd.read_excel(Path(datadir, 'invivo', 'i_Variables_gm', 'Brain_001_summary.xlsx'), sheet_name='DTI contrasts (all)')
invivo_file = Path(bidsder, 'tabular-v1.0.0/invivo-variables.tsv')

exvivo = Path(datadir, 'exvivo', 'e_Variables_gm').glob('*.xlsx')
ex1 = pd.read_excel(Path(datadir, 'exvivo', 'e_Variables_gm', 'Brain_ex001_summary.xlsx'), sheet_name='T2w contrast (all)') 
ex2 = pd.read_excel(Path(datadir, 'exvivo', 'e_Variables_gm', 'Brain_ex001_summary.xlsx'), sheet_name='DTI contrasts (all)')
exvivo_file = Path(bidsder, 'tabular-v1.0.0/exvivo-variables.tsv')

lab006_out = Path(bidsder, 'outputs-v1.0.0', 'tpl-NA216_atlas-Label006_dseg.tsv')

lab052_in = Path(datadir, 'invivo', 'i_Label052', 'Label052_classification.xlsx')
lab052_out = Path(bidsder, 'outputs-v1.0.0', 'tpl-NA216_atlas-Label052_dseg.tsv')

lab111_in = Path(datadir, 'invivo', 'i_Label111', 'Label111_classification.xlsx')
lab111_out = Path(bidsder, 'outputs-v1.0.0', 'tpl-NA216_atlas-Label111_dseg.tsv')

##
## create participants.tsv
##

print('Creating participants.tsv...')

## create sub-### in columns separate columns to merge immediately
invivo_dat.iloc[:,0] = [ f"sub-{x:03d}" for x in invivo_dat.iloc[:,0] ]
exvivo_dat.iloc[:,7] = [ x.replace('i', 'sub-') for x in exvivo_dat.iloc[:,7] ]

## fill in ex-vivo ID for BIDS id if no in-vivo data is present
exidx = exvivo_dat.loc[:,'in vivo Data'] == '-'
exvivo_dat.loc[exidx, 'in vivo Data'] = exvivo_dat.loc[exidx, 'ex vivo Database Number']
exvivo_dat.iloc[:,7] = [ x.replace('ex', 'sub-ex') for x in exvivo_dat.iloc[:,7] ]

## create merge ID
invivo_dat['participant_id'] = invivo_dat['In vivo Database Number']
exvivo_dat['participant_id'] = exvivo_dat['in vivo Data']

## create the bids subject ID based on in-vivo ID
data = pd.merge(invivo_dat, exvivo_dat, left_on='participant_id', right_on='participant_id', how='outer', sort=True)

## fix column names 
data.columns = ['ivdb', 'age', 'sex', 'weight', 'drop1', 'iv_t2', 'iv_dmri', 'iv_label', 'iv_aneth', 'iv_awake', 'exvivo_id', 'participant_id', 'exvivo_db', 'age_exvivo', 'sex_exvivo', 'drop2', 'ev_t2', 'ev_dmri', 'ev_label', 'ex_iv_map']

## dopr the obvious drops
data = data.drop(labels=['ivdb', 'drop1', 'exvivo_id', 'drop2', 'ex_iv_map'], axis=1)

## extract invivo image logical to a frame
data_images = data.loc[:,['participant_id', 'iv_t2', 'iv_dmri', 'iv_label', 'iv_aneth', 'iv_awake', 'ev_t2', 'ev_dmri', 'ev_label']]
data = data.drop(labels=['iv_t2', 'iv_dmri', 'iv_label', 'iv_aneth', 'iv_awake', 'ev_t2', 'ev_dmri', 'ev_label'], axis=1)

## check gender matches in-vivo / ex-vivo
# gtst = data.loc[~data.loc[:,'sex_exvivo'].isna(), ['sex','sex_exvivo']]
# if all(gtst.iloc[:,0] == gtst.iloc[:,1]):
data = data.drop(labels='sex_exvivo', axis=1)

## convert images 1/0 to logical
data_images = data_images.fillna(0)
data_images['iv_t2'] = data_images['iv_t2'].astype('bool')
data_images['iv_dmri'] = data_images['iv_t2'].astype('bool')
data_images['iv_label'] = data_images['iv_t2'].astype('bool')
data_images['iv_aneth'] = data_images['iv_t2'].astype('bool')
data_images['iv_awake'] = data_images['iv_t2'].astype('bool')
data_images['ev_t2'] = data_images['ev_t2'].astype('bool')
data_images['ev_dmri'] = data_images['ev_dmri'].astype('bool')
data_images['ev_label'] = data_images['ev_label'].astype('bool')

## add species (is this the species)
data['genus_species'] = 'callithrix-jacchus'

## reorder columns b/c I'm picky
data = data[['participant_id', 'genus_species', 'age', 'sex', 'weight', 'exvivo_db', 'age_exvivo']]

## write participants.tsv to disk for sanity checks
data.to_csv(partout, sep='\t', index=False, na_rep=np.nan) #, quoting=csv.QUOTE_NONNUMERIC)

## create a dictionary
partjson = {
    "participant_id": {"Description": "Identifies unique subjects."},
    "species": {"Description": "The species of the animal described by the subject ID.", "Levels": "callithrix jacchus"},
    "age": {"Description": "The age of the animal at observation.", "Units": 'months?'},
    "sex": {"Description": "The gender of the animal.", "Levels": {"M":"male", "F":"female"}},
    "weight": {"Description": "The weight of the animal at observation.", "Units": 'grams'},
    "exvivo_db": {"Description": "The participant ID used when acquiring exvivo data."},
    "age_exvivo": {"Description": "The age of the animal when the brain as preserved.", "Units": 'months'}
}

with open(partjson_out, "w") as outfile:
    json.dump(partjson, outfile)

##
## load and merge invivo/exvivo parcellation .xlsx sheets
##

invivo_data = []
invivo_subj = []

## build column names before loop starts
ix1_row2col = ix1[ix1.columns[1:4]].apply(lambda x: '-'.join(x.dropna().astype(str)), axis=1)
ix2_row2col = ix2[ix2.columns[1:4]].apply(lambda x: '-'.join(x.dropna().astype(str)), axis=1)

## sanity check that the rows match and assign a generic one
if all(ix1_row2col == ix2_row2col):
    print("Expected columns are found.")
    row2col = ix1_row2col

outcols = list(row2col + '_Anat-Volume') + list(row2col + '_T1w-mean') + list(row2col + '_T2w-mean') + list(row2col + '_T1T2-mean') + list(row2col + '_DWI-Volume') + list(row2col + '_AD-mean') + list(row2col + '_FA-mean') + list(row2col + '_MD-mean') + list(row2col + '_RD-mean')

print('Importing invivo data...')

for subj in invivo:

    print(f'Loading file: {subj}')
    invivo_subj.append('sub-' + subj.stem.split('_')[1])
    
    ## read in the first 2 sheets
    ## merge the hemisphere / label / abbreviation together into column stems
    ## build the column names
    ## pull the data into a vector

    try:
        ix1 = pd.read_excel(subj, sheet_name='T1&2w contrasts (all)') 
        ix1_row2col = ix1[ix1.columns[1:4]].apply(lambda x: '-'.join(x.dropna().astype(str)), axis=1)
        if all(ix1_row2col == row2col):
            outdata1 = np.concatenate([ix1.iloc[:,5], ix1.iloc[:,6], ix1.iloc[:,7], ix1.iloc[:,8]])
        else:
            print(' -- Columns are wrong.')
            outdata1 = np.zeros(1784,)
    except:
        print(' -- Modality Missing.')
        outdata1 = np.ones(1784,) * 999
            
    try:
        ix2 = pd.read_excel(subj, sheet_name='DTI contrasts (all)')
        ix2_row2col = ix2[ix2.columns[1:4]].apply(lambda x: '-'.join(x.dropna().astype(str)), axis=1)
        if all(ix2_row2col == row2col):
            outdata2 = np.concatenate([ix2.iloc[:,5], ix2.iloc[:,6], ix2.iloc[:,7], ix2.iloc[:,8], ix2.iloc[:,9]])
        else:
            print(' -- Columns are wrong.')
            outdata2 = np.zeros(2230,)
    except:
        print(' -- Modality Missing.')
        outdata2 = np.ones(2230,) * 999
            
    ## merge all the variables into a single array
    invivo_data.append(np.concatenate([outdata1, outdata2]))

## merge subject ID to variables

## build dataframe final
invivo_out = pd.DataFrame(invivo_data, columns = outcols)
invivo_out['participant_id'] = invivo_subj

## put subject ID in first column and sort by ID
tmp_subj = invivo_out.pop('participant_id')
invivo_out.insert(0, 'participant_id', tmp_subj)
invivo_out.sort_values(by = 'participant_id', inplace = True)

## replace 999 with missing
invivo_out.replace(999, np.nan, inplace = True)

## write to disk
invivo_out.to_csv(invivo_file, sep = '\t', index = False, na_rep = np.nan)

## create invivo-variables.json describing the columns...?

##
## exvivo data
##

exvivo_data = []
exvivo_subj = []

## build column names before loop starts
ex1_row2col = ex1[ex1.columns[1:4]].apply(lambda x: '-'.join(x.dropna().astype(str)), axis=1)
ex2_row2col = ex2[ex2.columns[1:4]].apply(lambda x: '-'.join(x.dropna().astype(str)), axis=1)

## sanity check that the rows match and assign a generic one
if all(ex1_row2col == ex2_row2col):
    print("Expected columns are found.")
    row2col = ex1_row2col

outcols = list(row2col + '_Anat-Volume') + list(row2col + '_T2w-mean') + list(row2col + '_DWI-Volume') + list(row2col + '_AD-mean') + list(row2col + '_FA-mean') + list(row2col + '_MD-mean') + list(row2col + '_RD-mean')

print('Importing exvivo data...')

for subj in exvivo:

    print(f'Loading file: {subj}')
    subsplit = subj.stem.split('_')
    if len(subsplit) == 3:
        exvivo_subj.append('sub-' + subj.stem.split('_')[1])
    elif len(subsplit) == 4:
        exvivo_subj.append('sub-' + subsplit[2].replace('i', ''))
    else:
        print('Something went wrong.')
        continue       

    ## deal with unkown loading issues
    try:
        ex1 = pd.read_excel(subj, sheet_name='T2w contrast (all)') 
        ex1_row2col = ex1[ex1.columns[1:4]].apply(lambda x: '-'.join(x.dropna().astype(str)), axis=1)
        if all(ex1_row2col == row2col):
            outdata1 = np.concatenate([ex1.iloc[:,5], ex1.iloc[:,6]])
        else:
            print(' -- Columns are wrong.')
            outdata1 = np.zeros(892,)
    except:
        print(' -- Modality Missing.')
        outdata1 = np.ones(2230,) * 999
            
    try:
        ex2 = pd.read_excel(subj, sheet_name='DTI contrasts (all)')
        ex2_row2col = ex2[ex2.columns[1:4]].apply(lambda x: '-'.join(x.dropna().astype(str)), axis=1)
        if all(ex2_row2col == row2col):
            outdata2 = np.concatenate([ex2.iloc[:,5], ex2.iloc[:,6], ex2.iloc[:,7], ex2.iloc[:,8], ex2.iloc[:,9]])
        else:
            print(' -- Columns are wrong.')
            outdata2 = np.zeros(892,)
    except:
        print(' -- Modality Missing.')
        outdata2 = np.ones(2230,) * 999
            
    ## merge all the variables into a single array
    exvivo_data.append(np.concatenate([outdata1, outdata2]))

## merge subject ID to variables

## build dataframe final
exvivo_out = pd.DataFrame(exvivo_data, columns = outcols)
exvivo_out['participant_id'] = exvivo_subj

## put subject ID in first column and sort by ID
tmp_subj = exvivo_out.pop('participant_id')
exvivo_out.insert(0, 'participant_id', tmp_subj)
exvivo_out.sort_values(by = 'participant_id', inplace = True)

## replace 999 with missing
exvivo_out.replace(999, np.nan, inplace = True)

## write to disk
exvivo_out.to_csv(exvivo_file, sep = '\t', index = False, na_rep = np.nan)

##
## move label .xlsx files to .tsv
##

print('Creating parcellation label files...')

lab006 = pd.DataFrame()
lab006['Number'] = np.arange(1,7)
lab006['Region Name of Label006.nii.gz'] = ['CSF', 'Gray Matter', 'White Matter', 'Ventricles', 'Brainstem', 'Cerebellum']
lab006['Region Name of Brain/MINDS Marmoset Reference Atlas (BMA)'] = np.nan
lab006.to_csv(lab006_out, sep = '\t', index = False, na_rep = np.nan)

lab052 = pd.read_excel(lab052_in)
lab052.to_csv(lab052_out, sep = '\t', index = False, na_rep = np.nan)

lab111 = pd.read_excel(lab111_in)
lab111.to_csv(lab111_out, sep = '\t', index = False, na_rep = np.nan)

