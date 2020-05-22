import FlightSuretyApp from '../../build/contracts/FlightSuretyApp.json';
import FlightSuretyData from '../../build/contracts/FlightSuretyData.json';
import Config from './config.json';
import Web3 from 'web3';

let config = null;


export default class Contract {
    
    constructor(network, callback) {

        
        config = Config[network];
       
        this.web3 = new Web3(new Web3.providers.WebsocketProvider(config.url.replace('http', 'ws'))); 
        this.flightSuretyApp = new this.web3.eth.Contract(FlightSuretyApp.abi, config.appAddress);
        this.flightSuretyData = new this.web3.eth.Contract(FlightSuretyData.abi, config.dataAddress);
        
        
        
        this.owner = null;
        this.airlines = [];
        this.airlineNames = [];
        this.flights = [];
        this.passengers = [];

        
        this.airlines[0] = config.firstAirline;
        this.airlineNames[0] = config.firstAirlineName;
        console.log("First Airline Deployed to app contract: "+this.airlines[0]);
        console.log("First Airline Name Deployed to app contract: "+this.airlineNames[0]);

        // Send the callback function sent via the constructor to the initialize function
        this.initialize(callback);
    }

    // Setup initial parameters. From Ganache retrieve the accounts[0] array which contains the addresses 
    // and private keys we are able to use to send transactions to the Blockchain. Also the accts[0]
    // is typically the address which deployed the Data and App contracts
    initialize(callback) {
        this.web3.eth.getAccounts((error, accts) => {
           
         //   console.log("Checking if Config is accessible insie the initialize function");
         //   console.log("config.appaddress: "+config.appAddress);

         // note all the code below is in the callback function of the web3.eth.getAccounts() function
            this.owner = accts[0];
            console.log("Inside Contract Class Owner Address: "+this.owner);

            console.log("Appaddress called in initialize function: "+config.appAddress);

            console.log('All accounts available from Ganache ');
            console.log(accts);

            
            //Add app contract as authorized contract to access Data contract
            this.flightSuretyData.methods
            .authorizeContract(config.appAddress)
            .send({ from: this.owner}, (error, result) => {
                console.log("Inside the authorizeContract function call to Data Contract: printing error and Result")
                console.log(error,result);
            });
            


            let counter = 2;
            


            // In the airlines array store the addresses of accts[2] to accts[4] as the last four 
            // airlines. The first airline was already registered during deployment
            while(this.airlines.length < 5) {
                this.airlines.push(accts[counter++]);
            }

            //Initialize airline Names
            this.airlineNames[1] = "Second";
            this.airlineNames[2] = "Third";
            this.airlineNames[3] = "Fourth";

            console.log("Airline Address Registered");
            this.airlines.map((airline)=> {
                console.log(airline);
            });

            console.log("Airline names:");
            this.airlineNames.map((name)=> {
                console.log(name);
            });

            //The next four addresses from accts[5] to accts[8] are stored as addresses of passengers
            while(this.passengers.length < 5) {
                this.passengers.push(accts[counter++]);
            }

            console.log("Passenger Addresses stored in the passenger array:  ");
            this.passengers.map((passenger)=> {
                console.log(passenger);
            });


            //Initialize flights to be registered
            this.flights[0] = {flight: 'flight1', address: this.airlines[0], timestamp: null};
            this.flights[1] = {flight: 'flight2', address: this.airlines[1], timestamp: null};
            this.flights[2] = {flight: 'flight3', address: this.airlines[2], timestamp: null};
            this.flights[3] = {flight: 'flight4', address: this.airlines[3], timestamp: null};
            console.log('Inside contract.js flights[] value:')
            console.log(this.flights[0]);
            console.log(this.flights[1]);
            console.log(this.flights[2]);
            console.log(this.flights[3]);

            //once the initial setup of the airline addresses and passenger address is done 
            // call the callback() function sent to the constructor of this class Conract
            callback();
        });
    }

    // internal function in this class Contract!!
    // Send in the callback function to this isOperational() function
    isOperational(callback) {
       let self = this;
       // From the ABI access the app contract function isOperational to send in a call to the contract
       // on the blockchain.
       // .call() is sent in the callback() function?? i guess this call responds with a promise/callback??
       self.flightSuretyApp.methods
            .isOperational()
            .call({ from: self.owner}, callback);
    }

    // fetchFlightStatus function will send a transaction to the App contracts function fetchFlightStatus
    // Which in turn takes airline address, flight name (string), and a timestamp 
    // The timestamp is set to the current time to use as the flight time.
    fetchFlightStatus(flight, callback) {
        let self = this;
        let statusResult = null;
        let statusError = null;
      
      //  console.log('Inside contract.js/fetchFlightStatus() function ');
      //  console.log('Below is the printout of the flight information sent from Index.js file ');
      //  console.log(flight);
        // Sending a transaction to the App contract function fetchFlightStatus. This app contract function
        // is triggering the oracle algorithm inside the app contract.
        self.flightSuretyApp.methods
            .fetchFlightStatus(flight.address, flight.flight, flight.timestamp)
            .send({ from: self.owner}, (error, result) => {
                console.log('Inside callback of contract.js/fetchFlightStatus function ');
                console.log(error,result);
                if(error) {
                    callback(error,result);
                }
                // callback(error, result, statusCodeRes);
                //console.log("Status Access - StatusCode = "+statusCodeRes);
        });

        // Events Listeners
        self.flightSuretyApp.events.FlightStatusResult({fromBlock: 0}, function (error, event) {
            console.log('Oracle event reported from processFlightStatus function of app contract')
            console.log(event);
            console.log('Event Emitted = '+event.event);
            console.log(event.returnValues.result);
            // console.log(error,event);
            console.log('Flight = '+event.returnValues.flight);
            console.log('statusCode ='+event.returnValues.statusCode);
            statusError = error;
            statusResult = event;
            callback(statusError, statusResult);
        });

        
        self.flightSuretyApp.events.OracleReport({fromBlock: 0}, function (error, event) {
            console.log('Oracle event reported from submitOracleResponse function of app contract')
            console.log('Event Emitted = '+event.event);
            // console.log(error,event);
            console.log('Flight = '+event.returnValues.flight);
            console.log('statusCode ='+event.returnValues.status);
        });
        
        


        // With the commented out "allEvents" listener below you could listen to all the events emitted by the app
        // contract.
        /*
        self.flightSuretyApp.events.allEvents({fromBlock: 0}, function (error, event) {
            console.log(error,event);
        });
        */

    }

    // registerAirline function will call the app's function to register a new airline
    registerAirline(airline, airlineName, registeredAirline, callback) {
        let self = this;
        self.flightSuretyApp.methods.registerAirline(airline, airlineName)
        .send({ from: registeredAirline, gas: config.gas}, (error, result) => {
            console.log("Inside the contract registerAirline function");
            console.log(error, result);
            callback(error, result);
        });
    }

    //approveAirline function will call the app's function send 10 ether by regeistered airlines to 
    // participate in the insurance program
    approveAirline(airline, callback) {
        let self = this;
        let premium = self.web3.utils.toWei("10", "ether");
        self.flightSuretyApp.methods.approveAirline()
        .send({ from: airline, value: premium, gas: config.gas}, (error, result) => {
            console.log('Inside the contract.js file - approveAirline function');
            console.log(error, result);
            callback(error, result);
        });
    }

    //Get the balance stored in the data app contract based on insurance premiums paid
    getInsuranceBalance(callback) {
        let self = this;
        self.flightSuretyData.methods.getInsuranceBalance().call({from: self.owner}, (error, result) => {
           // console.log("Inside the getInsuranceBalance Function");
           // console.log(error, result);
            callback(error, result);
        });
    }

    // function to send a transaction app contract to register a new flight which can be insured by passengers
    registerFlight(flight, callback) {
        let self = this;
        let payload = {
            flight: flight.flight,
            airline: flight.address,
            timestamp: flight.timestamp
        } 
        console.log('Inside the contract.js - Printing flight information stored as payload');
        console.log(payload);
        self.flightSuretyApp.methods.registerFlight(payload.flight, payload.airline, payload.timestamp)
        .send({ from: payload.airline, gas: config.gas}, (error, result) => {
            console.log('Inside the contract.js file - registerFlight callback function');
            console.log(error, result);
            callback(error, result);
        });
    }

    
    // function getFlightInfo() - Call the data contract getter function to retrive registered flight 
    // information from blockchain
    getFlightInfo(flight, callback) {
        let self = this;
        self.flightSuretyData.methods.flightInfoReturn(flight.flight, flight.address, flight.timestamp)
        .call({from: self.owner}, (error, result) => {
            console.log('Inside the contract.js file - getFlightInfo callback function');
            console.log(error, result);
            console.log("timestamp returned from blockchain for flight: "+result[3]);
            callback(error, result);
        });

    }

    
    buyFlightInsurance(flight, callback) {
        let self = this;
        console.log("Inside contract.js - buyFlightInsurance function - Flight information received: ");
        console.log(flight);
        let premium = self.web3.utils.toWei("1", "ether");
        self.flightSuretyApp.methods.buyFlightInsurance(flight.flight, flight.address, flight.timestamp)
        .send({ from: self.passengers[0], value: premium, gas: config.gas}, (error, result) => {
            console.log('Inside the contract.js file - buyFlightInsurance callback function');
            console.log(error, result);

            callback(error, result);
        });
        
    }

    // get all the passenger keys which paid insurance from the blockchain data for testing purposes
    getPassengerKeys(callback) {
        let self = this;
        console.log('** inside contract.js - getPassengerKeys() function');
        self.flightSuretyData.methods.getPassengerKeys().call({from: self.owner}, (error, result) => {
            console.log('**Printing all the passengerKeys');
            console.log(result);
            callback(error, result);
        });
    }

    // Get amount paid by the passenger to buy insurance

    getPassengerPayment(flight, callback) {
        let self = this;
        self.flightSuretyData.methods.getPassengerPayment(flight.flight, flight.address, flight.timestamp).call({from: self.passengers[0]}, (error, result) => {
            console.log("Inside the contract.js/getPassengerPayment() Function");
            // console.log(error, result);
            callback(error, result);
         });

    }

    // get amount credited to passenger due to a delayed flight
    getInsurancePaymentInfo(flight, callback) {
        let self = this;
        self.flightSuretyData.methods.getInsurancePaymentInfo(flight.flight, flight.address, flight.timestamp ,self.passengers[0]).call({from: self.owner}, (error, result) => { 
            console.log('**Inside contract.js- getInsurancePaymentInfo() function **');
            console.log('Amount credited to Passenger[0] in wei = '+result);
            callback(error, result);
        });

    }


    // withdraw credit from insurance payout from app and data contract
    passengerCreditWithdraw(flight, callback) {
        let self = this;
        self.flightSuretyApp.methods.passengerCreditWithdraw(flight.flight, flight.address, flight.timestamp)
        .send({ from: self.passengers[0], gas: config.gas}, (error, result) => {
            console.log('**Inside contract.js - passengerCreditWithdraw function');
            console.log(error, result);
            if(error) {
                callback(error, result);
            }
        });

        // Events Listeners
        self.flightSuretyApp.events.CreditWithdrawal({fromBlock: 0}, function (error, event) {
            //visual test to see if money was sent to correct address
            console.log('Money sent to address = '+event.returnValues.passengerAddress);
            console.log('Passenger[0] address = '+self.passengers[0]);
            callback(error,event);
        });


    }
    

    
}