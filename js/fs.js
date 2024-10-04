import fs from 'fs';
import {expect} from 'chai';

export async function loadABI(path) {
    try {
        const artifact = JSON.parse(fs.readFileSync(path, 'utf8'));
        const contractABI = artifact.abi;
        return contractABI;
    } catch (error) {
        console.error('Error reading ABI:', error);
        return null;
    }
}

export async function loadAddress(path) {
    try {
        const run = JSON.parse(fs.readFileSync(path, 'utf8'));
        expect(run.transactions.length).to.equal(1);
        expect(run.transactions[0].contractName).to.equal("SafeHarborRegistry");

        const contractAddr = run.transactions[0].contractAddress;
        return contractAddr;
    } catch (error) {
        console.error('Error reading address:', error);
        return null;
    }
}