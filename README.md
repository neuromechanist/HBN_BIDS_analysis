# Analysis Pipleine for the Healthy Brain Network Project
This repository contains the analysis pipeline for the Healthy Brain Network project. The pipeline is written in Matlab, mostly using custom scripts, and based on the most recent EEGLAB version (v2023.0). The pipeline is designed to be run on the SDSC Expance cluster, but can be run on any machine with Matlab and EEGLAB installed.

## Getting Started
To get started, clone this repository to your local machine. The pipeline is designed to be run in a specific order, with each step building on the previous one. The steps are as follows:
1. Preprocessing
2. Artifact Rejection (mainly channel level)
3. ICA
4. Dipfit

There is also a separate script for helping export the raw HBN data to the BIDS format.

We have also included a script to load the BIDS data into EEGLAB. This script is not part of the main pipeline but can be useful for loading the data into EEGLAB and performing some preliminary analysis.

## BIDS Conversion

The main curation steps to convert the raw HBN data to BIDS format are as follows:
1. Download the raw HBN data from the HBN S3 bucket.

```mermaid
graph TD
    A[Start] --> B
    B[Load data] -->|EEG and Behavioral data| C
    B -->|EEG and Psychopathologic data| CC
    C[Replace Event Codes with Descriptions] --> D
    D[Augment Behavioral Events] -->|full event files| E
    E[Augment Behavior Events] -->|Augmented Event data| F
    F[Add HED annotation and sidecar] --> G
    G[Quality Check:\n 1. "Confirm (and correct) sampling frequency", \n 2. data length, \n 3. Event counts and presence] -->|quality details saved for reference| H
    H[Add availability flag based on data qality] -->I
    I[Create BIDS datasets]
    CC[Build Participant Information] --> DD
    DD[Inspect the EEG data: \n 1- Check for dicontinuities \n 2- Check for missing events \n 3- Remove incompatible fields] --> G

    classDef inputOutput fill:#81DEE7,stroke:#333,stroke-width:2px;
    class A,B,C,D,E,F,G,H,I,J,CC,DD inputOutput;
    
```
