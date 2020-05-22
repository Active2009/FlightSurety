
var FlightSuretyApp = artifacts.require("FlightSuretyApp");
var FlightSuretyData = artifacts.require("FlightSuretyData");
var BigNumber = require('bignumber.js');

// Config is assigned a function. So Config is a function. In the function new instances of the app and data contract are deployed.
// This function returns an object with all the information about the data and app contract deployed and other relavant information
// When calling this function, send in the accounts array as an argument. This function will be called from
// flightSurety.js file and accounts array will be sent to this function
var Config = async function(accounts) {
    
    // These test addresses are useful when you need to add
    // multiple users in test scripts
    let testAddresses = [
        "0x69e1CB5cFcA8A311586e3406ed0301C06fb839a2",
        "0xF014343BDFFbED8660A9d8721deC985126f189F3",
        "0x0E79EDbD6A727CfeE09A2b1d0A59F7752d5bf7C9",
        "0x9bC1169Ca09555bf2721A5C9eC6D69c8073bfeB4",
        "0xa23eAEf02F9E0338EEcDa8Fdd0A73aDD781b2A86",
        "0x6b85cc8f612d5457d49775439335f83e12b8cfde",
        "0xcbd22ff1ded1423fbc24a7af2148745878800024",
        "0xc257274276a4e539741ca11b590b9447b26a8051",
        "0x2f2899d6d35b1a48a4fbdc93a37a72f264a9fca7"
    ];


    let owner = accounts[0];
    let firstAirline = accounts[1];
    let firstAirlineName = "First";

    // By default the below contracts which were deployed and deployed by the accounts[0] address
    // as none was specified in the ".new" function
    let flightSuretyData = await FlightSuretyData.new(accounts[1], firstAirlineName);
    //RG: pass in the address of the data contract to the app contract to facilitate interface from app to data contract
    let flightSuretyApp = await FlightSuretyApp.new(flightSuretyData.address);

// return all the data/information associated with the data and app contracts deployed. Owner of the contracts which were deployed
// deployed contract Javascript objects are also returned.
    return {
        owner: owner,
        firstAirline: firstAirline,
        firstAirlineName: firstAirlineName, 
        weiMultiple: (new BigNumber(10)).pow(18),
        testAddresses: testAddresses,
        flightSuretyData: flightSuretyData,
        flightSuretyApp: flightSuretyApp
    }
}

// Export the Config function as an object. This object can be used in the flightSurety.js as needed to 
// test the contracts.
module.exports = {
    Config: Config
};
