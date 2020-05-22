var Test = require('../config/testConfig.js');
var BigNumber = require('bignumber.js');


contract('Flight Surety Tests', async (accounts) => {

  var config;
  before('setup contract', async () => {
    
    config = await Test.Config(accounts);
    
    await config.flightSuretyData.authorizeContract(config.flightSuretyApp.address);
  });

  /****************************************************************************************/
  /* Operations and Settings                                                              */
  /****************************************************************************************/

  it(`(multiparty) has correct initial isOperational() value - Test 1`, async function () {

    // Get operating status
    let status = await config.flightSuretyData.isOperational.call();
    assert.equal(status, true, "Incorrect initial operating status value");

  });

  it(`First airline was successfully added to contract at deployment of Data Contract - Test 2`, async function () {

    // Get operating status
    const airlineData = await config.flightSuretyData.airlineInfoReturn.call(config.firstAirline);
    
      
    assert.equal(airlineData[0],"First","Airline Name did not get Registered");
    assert.equal(airlineData[1],config.firstAirline,"Airline address did not get Registered");
    assert.equal(airlineData[2],false,"Airline was not supposed to be approved yet");
    assert.equal(airlineData[3],true,"Airline was supposed to be the first to be registered");
    assert.equal(airlineData[4],1,"Airline serial Number is not equal to 1");

  });

  it(`App and Data security is setup Properly- Test 3`, async function() {
    // Test if the app contract was successfully added as an approved contract to access data app functions.
    let value1 = await config.flightSuretyData.isAuthorizedContract.call(config.flightSuretyApp.address);
    // Test to make sure other random address is not part of the approved contracts.
    let value2 = await config.flightSuretyData.isAuthorizedContract.call(config.testAddresses[0]);
   // console.log('value returned from contract ='+value);
    assert.equal(value1,1,"Authorized contract address not properly added");
    assert.equal(value2,0,"contract address should not be authorized");
  });

  it(`Only Data Contract Owner can authorize an address to access data contract - Test 4`, async function() {
      let accessDenied = false;
      try {
        // config.testAddresses[1] is not the owner of the Data contract and here we test to see that when
        // this random address tried to add an address as authorized to the data contract it will lead to an error
        await config.flightSuretyData.authorizedContract(config.testAddresses[0],{from: config.testAddresses[1]});
      }
      catch(e) {
        accessDenied = true;
      }
      assert.equal(accessDenied, true, "Any one can authorize contract addresses to data contract");
    
  });


  it(`Succefully interfaced App contract to Data contract - Test 5`, async function() {
    // call the isOperational Function of app contract which calls the isOperational function in data contract
    let status = await config.flightSuretyApp.isOperational.call();
  //  console.log("Satus value ="+status);
    assert.equal(status, true, "Incorrect initial operating status value");
  });

  it(`Succefully able to register new airlines by existing four airlines - Test 6`, async function() {
    let result2 = await config.flightSuretyApp.registerAirline(accounts[2],"Second", {from: accounts[1]});
    // console.log(result2.logs[0].args.airlineName);
    let result3 = await config.flightSuretyApp.registerAirline(accounts[3],"Third", {from: accounts[2]});
    // console.log(result3.logs[0].args.airlineName);
    let result4 = await config.flightSuretyApp.registerAirline(accounts[4],"Fourth",{from: accounts[3]});
    // console.log(result4.logs[0].args.airlineName);
    
    // string airlineName was emitted as an event in app contract everytime a new airline is successfully regsitered
    assert.equal(result2.logs[0].args.airlineName,"Second","Error - Second airline was not registered");
    assert.equal(result3.logs[0].args.airlineName,"Third","Error - Third airline was not registered");
    assert.equal(result4.logs[0].args.airlineName,"Fourth","Error - Second airline was not registered");
    
  });

  it(`Succesfully added multiparty consensus to Register new airline - Test 7`, async function() {
    // We send in votes by two airlines accounts[1] and accounts[2] to register accounts[5] as the fifth
    // airline. This should trigger the consensus algorith in the app contract as this is fifth airline we
    // are trying to register
    let result5 = await config.flightSuretyApp.registerAirline(accounts[5],"Fifth", {from: accounts[1]});
   // console.log(result5);
    let result6 = await config.flightSuretyApp.registerAirline(accounts[5],"Fifth", {from: accounts[2]});
   // console.log(result6);
   // console.log(result6.logs[0].args.airlineName);
    
   // once 2 registered airlines vote out of the 4 registered airlines consensus is reached and our contracts
   // should be able to add accounts[5] as the new registered airline
    let isAirlineRegistered = await config.flightSuretyData.isAirlineRegistered(accounts[5]);

    assert.equal(isAirlineRegistered,true,"Error - Multiparty consensus did not work for adding new airlines");

  });

  it(`Check multiparty consensus resits multiple votes from same airline - Test 8`, async function() {
    let result5 = await config.flightSuretyApp.registerAirline(accounts[6],"Sixth", {from: accounts[1]});
   // console.log(result5);
    let result6 = await config.flightSuretyApp.registerAirline(accounts[6],"Sixth", {from: accounts[2]});
   // console.log(result6);

   let isDuplicateVote = false;
    try {
      let result7 = await config.flightSuretyApp.registerAirline(accounts[6],"Sixth", {from: accounts[2]});
    }
    catch(e){
      //console.log(e);
      // Since accounts[2] tried to vote twice, the app contract should abort and the transaction should lead to
      // an error and reach this catch block of the code
      isDuplicateVote = true;
    }
    
    let result8 = await config.flightSuretyApp.registerAirline(accounts[6],"Sixth", {from: accounts[3]});
    // console.log(result8);
    // console.log(result8.logs[0].args.airlineName);
    
    let isAirlineRegistered = await config.flightSuretyData.isAirlineRegistered(accounts[6]);

    assert.equal(isDuplicateVote,true,"Error - Multiple voting by same airline is occuring");
    assert.equal(result8.logs[0].args.airlineName,"Sixth","Error - Multiple voting by same airline is occuring");
    assert.equal(isAirlineRegistered,true,"Error - Multiparty consensus did not work for adding new airlines");

  });

  it(`Check registered airline is Approved when premium of 10 ether is paid - Test 9`, async function() {
    
    let premium = web3.utils.toWei("10", "ether");
   // console.log("Value stored in premium variable: " +premium);
    // Send 10 ether to the app contract to approve airline accounts[1]
    let result1 = await config.flightSuretyApp.approveAirline({from: accounts[1], value: premium});
    
   // console.log(result1);
   // console.log("Airline 1 Name: " +result1.logs[0].args.airlineName);
    
   // Check if the airline status at accounts[1] was changed to true
    let isAirlineApproved = await config.flightSuretyData.getAirlineStatus(accounts[1]);
   // console.log("Airline 1 Approval Status: " +isAirlineApproved);

   
   // check if 10 ether was successfully added to the insurance pool in the Data contract
    let contractBalance = await config.flightSuretyData.getInsuranceBalance();
   
    

    // Check if the event Approved(airlineName) was properly emitted
    assert.equal(result1.logs[0].args.airlineName,"First","Error - Airline was not approved properly");
    assert.equal(isAirlineApproved,true,"Error - Airline Approval Status was not properly updated");
    assert.equal(contractBalance,premium,"Error - 10 Ether sent was not properly stored in the Data Contract");

  });


  
});