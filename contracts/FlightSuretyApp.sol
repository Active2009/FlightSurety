pragma solidity ^0.4.24;

// It's important to avoid vulnerabilities due to numeric overflow bugs
// OpenZeppelin's SafeMath library, when used correctly, protects agains such bugs
// More info: https://www.nccgroup.trust/us/about-us/newsroom-and-events/blog/2018/november/smart-contract-insecurity-bad-arithmetic/

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */
contract FlightSuretyApp {
    using SafeMath for uint256; // Allow SafeMath functions to be called for all uint256 types (similar to "prototype" in Javascript)

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    // Flight status codees
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;

    address private contractOwner;          // Account used to deploy contract

    // Variable for multi party consensus to add new airlines to the registered airlines
    // multiCalls[] array will store the addresses of the already registered airlines which voted to add the new airline
    address[] multiCalls = new address[](0);

    //RG: removed the struct Flight and mapping flights to Data contract from the starter code

    //RG: create a variable to store reference to the data contract from app contract
    FlightSuretyData flightSuretyData;

     /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/

    /**
    * @dev event emitted when a new airline is registered
    */
    event Registered(string airlineName);

    /**
    * @dev event emitted when a new flight is registered
    */
    event RegisteredFlight(string flight);

    // Event emitted when a registered airline is approved after paying 10 ether
    event Approved(string airlineName);

    // Event emitted once a passenger successfully buys insurance for a flight
    event PassengerInsured(bytes32 passengerKey, address passengerAddress);

    // Event emitted once a passenger successfully withdraws money credit to their account
    event CreditWithdrawal(address passengerAddress);


    /********************************************************************************************/
    /*                                       FUNCTION MODIFIERS                                 */
    /********************************************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
    * @dev Modifier that requires the "operational" boolean variable to be "true"
    *      This is used on all state changing functions to pause the contract in
    *      the event there is an issue that needs to be fixed
    */
    /*
    modifier requireIsOperational()
    {
         // Modify to call data contract's status
         //RG: calling the data contract funciton to check if the contract is active or paused
        bool status = flightSuretyData.isOperational();
        require(status == true,"Contract is currently not operational");
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }
    */

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller not a contract owner");
        _;
    }

    /********************************************************************************************/
    /*                                       CONSTRUCTOR                                        */
    /********************************************************************************************/

    /**
    * @dev Contract constructor
    *
    */
    constructor
                                (address dataContractAddress
                                )
                                public
    {
        contractOwner = msg.sender;
        //RG: create an instance of the data contract using the address of the data contract sent when deploying this contract
        flightSuretyData = FlightSuretyData(dataContractAddress);
    }

    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    function isOperational()
                            public
                            view
                            returns(bool)
    {
        //RG: calling the data contract function to check if the contract is paused or active
        return flightSuretyData.isOperational();  // Modify to call data contract's status
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/


   /**
    * @dev Add an airline to the registration queue
    *
    */
    function registerAirline
                            (address airlineAddress,
                            string memory airlineName
                            )
                            public
    {
        uint256 counter = flightSuretyData.airlineCounter();
        // Verify if the number of airlines registered is less than 5
        if(counter < 4) {
            // verify if the msg.sender registering the new airline is already a registered airline
            bool isRegistered = flightSuretyData.isAirlineRegistered(msg.sender);
            require(isRegistered == true, "msg.sender not registered");
            flightSuretyData.registerAirline(airlineAddress, airlineName);
            emit Registered(airlineName);
        }
        // Implement the multiparty consensus in the else loop once first 4 airlines are registered
        else {
            // verify if the msg.sender registering the new airline is already a registered airline
            bool isRegistered1 = flightSuretyData.isAirlineRegistered(msg.sender);
            require(isRegistered1 == true, "msg.sender not registered");

            // boolean flag to track if msg.sender is voting multiple times
            bool isDuplicate = false;
            // Check if msg.sender has already voted to register the new airline
            if(multiCalls.length > 0) {
                for(uint c=0; c<multiCalls.length; c++) {
                    if(multiCalls[c] == msg.sender){
                        // msg.sender already voted. This transaction is a duplcicate vote abort this function
                        isDuplicate = true;
                        break;
                    }
                }
            }

            // If for loop above confirmed voting duplicacy then abort this function by the require statement below
            require(isDuplicate == false,"Airline has already called this function");
            multiCalls.push(msg.sender);
            uint256 arrayLength = multiCalls.length;
            uint256 twiceLength = arrayLength.mul(2);
            // consensus check to see if the new airline received enough votes
            // Need more than half of the registered airlines to vote for this new airline
            if(twiceLength >= counter) {
               flightSuretyData.registerAirline(airlineAddress, airlineName);
               emit Registered(airlineName);
               multiCalls = new address[](0);
            }
        }

    }

   /**
    * @dev Function for a registered airline to call to send 10 ether.
    * Once 10 ether is sent, the airline will be approved to participate in the insurance program
    *
    */
    function approveAirline() external payable {
        // Check if the msg.sender is a registered airline
        bool isRegistered = flightSuretyData.isAirlineRegistered(msg.sender);
        require(isRegistered == true, "msg.sender not registered");
        // Check if airlines sent 10 ether to register
        require(msg.value == 10 ether,"Send 10 ether to the contract");
        flightSuretyData.approveAirline.value(msg.value)(msg.sender);
        string memory airlineName = flightSuretyData.getAirlineName(msg.sender);
        emit Approved(airlineName);
    }

//function getBalance(): Getter function to retrieve value stored in this app contract
// Helper function to test the code

    function getBalance() external view returns(uint256) {
       return address(this).balance;
    }


   /**
    * @dev Register a future flight for insuring.
    *
    */
    function registerFlight(string memory flight, address airline, uint256 timestamp)
                                public
    {
        // verify if the address airline registering the new flight is already an approved airline
            bool isApproved = flightSuretyData.isAirlineApproved(airline);
            require(isApproved == true, "Airline is not approved to participate in insurance");
            flightSuretyData.registerFlight(flight, airline, timestamp);
            emit RegisteredFlight(flight);
    }

/**
* @dev passenger can buy insurance for a flight
* Max 1 ether can be sent by the passenger to buy insurance
* Check if the flight is registered first
* Check if passenger already bought the same flight insurance before
* Call data app function to buy the insurance and store the data
 */
    function buyFlightInsurance(string memory flight, address airline, uint256 timestamp) public payable {
        require(msg.value <= 1 ether, 'Send maximum of 1 ether to buy');

        bytes32 flightKey = keccak256(abi.encodePacked(flight, airline, timestamp));
        bool flightRegistered = flightSuretyData.isFlightRegistered(flightKey);
        require(flightRegistered == true, "Flight not Registered");

        // passengerKey is a hash of flight information and passenger address
        bytes32 passengerKey = keccak256(abi.encodePacked(flight, airline, timestamp, msg.sender));
        bool insuranceStatus = flightSuretyData.isPassengerInsured(passengerKey);
        require(insuranceStatus == false, "Passenger already bought insurance for this flight.");

        flightSuretyData.buyFlightInsurance.value(msg.value)(flightKey, passengerKey, msg.sender);
        emit PassengerInsured(passengerKey, msg.sender);

    }

/**
* @dev passenger can withdraw insurance payment credited to passenger account
* Call data app passengerCreditWithdraw() function to send funds to passenger (=msg.sender)
 */

    function passengerCreditWithdraw(string memory flight, address airline, uint256 timestamp) public payable {
        uint256 balance = flightSuretyData.getInsurancePaymentInfo(flight, airline, timestamp, msg.sender);
        require(balance > 0, 'Passenger has no insurance payment credit outstanding');
        bytes32 passengerKey = keccak256(abi.encodePacked(flight, airline, timestamp, msg.sender));
        flightSuretyData.passengerCreditWithdraw(passengerKey, msg.sender);
        emit CreditWithdrawal(msg.sender);

    }


// ORACLE ALGORITHM FUNCTIONS FOLLOW BELOW

   /**
    * @dev Called after oracle has updated flight status
    *
    */
    // Once the flight status is received, take appropriate action of paying out insurance money
    // if flight was delayed.
    function processFlightStatus(address airline, string memory flight, uint256 timestamp, uint8 statusCode)
                                internal
    {
        string memory result;
        if(statusCode == 0) {
            result = 'StatusCode = 0, Flight status unknown, no insurance payments made, Checkin Later';
            emit FlightStatusResult(result, statusCode, flight);
        }

        if(statusCode == 10) {
            result = 'StatusCode = 10, Flight is on time, no insurance payments made';
            emit FlightStatusResult(result, statusCode, flight);
        }

        if(statusCode == 20 || statusCode == 30 || statusCode == 40 || statusCode == 50) {

            // pay all passengers who insured by crediting their addresses with the amount they are owed
            bytes32 flightKey = keccak256(abi.encodePacked(flight, airline, timestamp));
            flightSuretyData.payInsurance(flightKey);
            result = 'StatusCode = 20 or 30 or 40 or 50, Flight is late, All passengers eligible were paid- Passenger can withdraw funds';
            emit FlightStatusResult(result, statusCode, flight);
        }

    }


    // Generate a request for oracles to fetch flight information
    function fetchFlightStatus(address airline, string flight, uint256 timestamp) external
    {
        bytes32 flightKey = keccak256(abi.encodePacked(flight, airline, timestamp));
        bool flightRegistered = flightSuretyData.isFlightRegistered(flightKey);
        require(flightRegistered == true, "Flight not Registered");

        uint8 index = getRandomIndex(msg.sender); //Get a random number between 0 to 9 with seed of msg.sender and other numbers

        // Generate a unique key (hash) for storing the flight status request
        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));
        // Store this current flight status check request into the data base as a Struct of ResponseInfo.
        // This is stored via mapping using key = hash generated above and mapped to ResponseInfo
        // Response Info stores the address of the person sending the status update request and
        // initially assigns a status open = true indicating that the flight status information has
        // not been received by the App contract from Oracles yet
        oracleResponses[key] = ResponseInfo({
                                                requester: msg.sender,
                                                isOpen: true
                                            });

    // The index is a random number generated between 0 to 9. Oracles have 3 (0 to 9) random numbers
    // assigned when they registered. Only Oracles with matching indexes are allowed to provide
    // flight status information. This is done to provide randomness in the Oracle submission so that
    // Oracles cannot collude easily I think??

    // Emit a event with the random index value and flight information. I think the server which simulates
    // the oracles will be listening to see if this event is emitted.
        emit OracleRequest(index, airline, flight, timestamp);
    }


// region ORACLE MANAGEMENT

    // Incremented to add pseudo-randomness at various points
    uint8 private nonce = 0;

    // Fee to be paid when registering oracle
    uint256 public constant REGISTRATION_FEE = 1 ether;

    // Number of oracles that must respond for valid status
    uint256 private constant MIN_RESPONSES = 3;


    struct Oracle {
        bool isRegistered;
        uint8[3] indexes; //Each Oracle registered has an array of three random integers between
                          // 0 to 9. Each element of array is non-duplicating.
                          // This array is generated when an Oracle registers
    }

    // Track all registered oracles
    mapping(address => Oracle) private oracles;

    // Model for responses from oracles
    // The responses mapping is a mapping from the uint8 which will be the status code of the flight
    // This is mapped to an array of address. So all the Oracles addresses which respond with a
    // particular status code are stored into this array. This can be used to group the
    // addresses by the Status Code. So all the addresses which provided the same status code are
    // stored into this mapping
    struct ResponseInfo {
        address requester;                              // Account that requested status
        bool isOpen;                                    // If open, oracle responses are accepted
        mapping(uint8 => address[]) responses;          // Mapping key is the status code reported
                                                        // This lets us group responses and identify
                                                        // the response that majority of the oracles
    }

    // Track all oracle responses
    // Key = hash(index, flight, timestamp)
    mapping(bytes32 => ResponseInfo) private oracleResponses;

    // Event fired each time an oracle submits a response
    event FlightStatusInfo(address airline, string flight, uint256 timestamp, uint8 status);

    event OracleReport(address airline, string flight, uint256 timestamp, uint8 status);

    // Event fired when flight status request is submitted
    // Oracles track this and if they have a matching index
    // they fetch data and submit a response
    event OracleRequest(uint8 index, address airline, string flight, uint256 timestamp);

    // Event emitted by process flight to alert the status of flight based on information provided by Oracles
    event FlightStatusResult(string result, uint8 statusCode, string flight);


    // Register an oracle with the contract
    function registerOracle() external payable
    {
        // Require registration fee
        require(msg.value >= REGISTRATION_FEE, "Registration fee is required");

        // generateIndexes returns an array of 3 numbers. These three numbers are non-repeating between 0 to 9
        uint8[3] memory indexes = generateIndexes(msg.sender);

        oracles[msg.sender] = Oracle({
                                        isRegistered: true,
                                        indexes: indexes
                                    });
    }

    // Returns the Array "indexes" stored by each Oracle. This function has to be called
    // by a registered Oracle
    function getMyIndexes() external view returns(uint8[3])
    {
        require(oracles[msg.sender].isRegistered, "Not registered as an oracle");

        return oracles[msg.sender].indexes;
    }




    // Called by oracle when a response is available to an outstanding request
    // For the response to be accepted, there must be a pending request that is open
    // and matches one of the three Indexes randomly assigned to the oracle at the
    // time of registration (i.e. uninvited oracles are not welcome)
    function submitOracleResponse(uint8 index, address airline, string flight, uint256 timestamp,
                        uint8 statusCode)
                        external
    {
        require((oracles[msg.sender].indexes[0] == index) || (oracles[msg.sender].indexes[1] == index) || (oracles[msg.sender].indexes[2] == index), "Index does not match oracle request");

        // The key below was the same Hash generated before in the fetchFlightStatus function just before
        // a flight status request event was emitted
        bytes32 key = keccak256(abi.encodePacked(index, airline, flight, timestamp));
        require(oracleResponses[key].isOpen, "Flight or timestamp do not match oracle request - Or Oracel Request has been closed");

        // address of the Oracle is stored inside the mapping responses. The mapping responses
        // is an array of addresses located at each Status code returned by the Oracle.
        oracleResponses[key].responses[statusCode].push(msg.sender);

        // emit the OracleReport event to say that a Oracle response was received for an ongoing open request
        emit OracleReport(airline, flight, timestamp, statusCode);

        // stop and revert back if statusCode is invalid code. Information is recorded for invalid code
        // to judge performance of Oracles
        require(statusCode == 0 || statusCode == 10 || statusCode == 20 || statusCode == 30 ||
                statusCode == 40 || statusCode == 50, "Invalid Status Code Submitted by Oracle");

        // Information isn't considered verified until at least MIN_RESPONSES
        // oracles respond with the *** same *** information

        if (oracleResponses[key].responses[statusCode].length >= MIN_RESPONSES) {
            // Change the flag in the oracleResponses to stop accepting oracle responses since
            // the required number of responses to make a decision on flight status were received
            oracleResponses[key].isOpen = false;
            // The event FlightStatusInfo signals that Flight Status information requested was
            // obtained for that particular flight and the statuscode of whether the flight was delayed or
            // not is emitted out along with the flight information

            emit FlightStatusInfo(airline, flight, timestamp, statusCode);

            // Handle flight status as appropriate
            // I need to write the code for this function once the flight status is obtained
            // In this function we check if flight was delayed or not and if delayed we payout the insurance
            // to passenger who insured
            processFlightStatus(airline, flight, timestamp, statusCode);
        }
    }


    function getFlightKey
                        (
                            address airline,
                            string flight,
                            uint256 timestamp
                        )
                        pure
                        internal
                        returns(bytes32)
    {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    // Returns array of three non-duplicating integers from 0-9
    function generateIndexes(address account) internal returns(uint8[3])
    {
        uint8[3] memory indexes;
        indexes[0] = getRandomIndex(account);

        indexes[1] = indexes[0];
        while(indexes[1] == indexes[0]) {
            indexes[1] = getRandomIndex(account);
        }

        indexes[2] = indexes[1];
        while((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
            indexes[2] = getRandomIndex(account);
        }
        return indexes;
    }

    // Returns a random number between 0 and 9. Using the hash of (blockhash, msg.sender)
    function getRandomIndex(address account) internal returns (uint8) {
        uint8 maxValue = 10;

        // Pseudo random number...the incrementing nonce adds variation
        uint8 random = uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - nonce++), account))) % maxValue);

        if (nonce > 250) {
            nonce = 0;  // Can only fetch blockhashes for last 256 blocks so we adapt
        }

        return random;
    }

// endregion

}

//RG: add the syntax for interfacing the data contract into the app contract
contract FlightSuretyData {
    function isOperational() external view returns(bool);
    function registerAirline(address airlineAddress, string memory airlineName) public;
    function registerFlight(string memory flight, address airline, uint256 timestamp) public;
    uint256 public airlineCounter;
    function isAirlineRegistered(address airline) public view returns(bool);
    function isAirlineApproved(address airline) public view returns(bool);
    function approveAirline(address airlineAddress) external payable;
    function getAirlineName(address airlineAddress) external view returns(string memory airlineName);
    function isFlightRegistered(bytes32 flightKey) external view returns(bool);
    function isPassengerInsured(bytes32 passengerKey) external view returns(bool);
    function buyFlightInsurance(bytes32 flightKey, bytes32 passengerKey, address passengerAdd) external payable;
    function payInsurance(bytes32 flightKey) external;
    function passengerCreditWithdraw(bytes32 passengerKey, address passenger) external payable;
    function getInsurancePaymentInfo(string memory flight, address airline, uint256 timestamp, address passenger) public view returns(uint256);

}
