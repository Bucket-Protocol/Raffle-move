# Bucket Raffle System

<img width="1505" alt="image" src="https://github.com/EasonC13/Sui-Raffle-frontend/assets/43432631/b5e26542-48e1-4121-98e6-4b46d8133110">

Let's raffle on Sui!

- [Smart Contract (Click me)](https://github.com/EasonC13/raffle-move)
- [Front-end (Click me)](https://github.com/EasonC13/Sui-Raffle-frontend)
- [Raffle Module on Testnet (Click me)](https://suiexplorer.com/object/0x3a464a3cdafa0a23645d2082599a87780d47259719cba4e9a0fe83a0d552f05f?module=raffle&network=testnet)

## Motivation
Bucket Protocol organizes many raffle events. For example, to celebrate our Mainnet launch yesterday, we gave away 300 Sui to 5 lucky users from 375 participants who minted our Testnet NFT. 

Nevertheless, we found that the existing lottery system in Web2 is not truly random. Sui Network uses Drand (Distributed Randomness Beacon) for generating random numbers. Therefore, we hope to be able to conduct the lottery directly on Sui using this random number and directly transfer the prize (Coin) to the user's Sui Address.

## Current Progress
We successfully built the MVP on June 29, where users can start a new raffle with specified participants' addresses and the number of winners. Then, the package will use the Sui network’s Drand randomness to pick winners randomly. Finally, the reward coin will be distributed equally to all winners.

## Future Works
Next, we aim to enhance our lottery service by automatically fetching a specific list of NFT owners and filtering them based on custom filters such as holding duration, quantity owned, NFT content, and more. This will enable the NFT project marketing team to effortlessly select lucky winners from their collectors. Additionally, we will integrate with Kiosk, allowing project owners to easily launch their own raffles and enabling users to collect raffle tickets as NFTs effortlessly.
