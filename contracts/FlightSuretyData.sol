pragma solidity ^0.4.24;

import "../node_modules/openzeppelin-solidity/contracts/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /********************************************************************************************/
    /*                                       DATA VARIABLES                                     */
    /********************************************************************************************/

    address private contractOwner;                                      // Account used to deploy contract
    bool private operational = true;                                    // Blocks all state changes throughout the contract if false
    uint256 public airlineCounter = 0; //counter to track total number of airlines registered
    uint256 public insuranceBalance = 0; // variable to track total value stored in the contract

    // RG: Moved the struct Flight and mapping flights from app contract to data contract because I want to persist this data even if app is upgraded
    // struct Flight used to store information about the flight
    struct Flight {
        bool isRegistered;
        string flight;
        address airline;
        uint256 timestamp;
        bytes32 key;
    }
    mapping(bytes32 => Flight) private flights; //Mapping to store each flight information in the flight struct

    //RG: Struct to Store Airlines data
    // bool isApproved: used to track if the airline has paid the 10 ether to participate in the insurance program
    // bool isFirst: Used to track if that particular airline was the first airline to be added
    // uint256 serialNumber: Used to track the order in which that ailine was added
    // addresse airlineAddress: Will be used to store the address of the registered airline
    struct Airline {
        bool isApproved;
        string name;
        bool isFirst;
        address airlineAddress;
        uint256 serialNumber;
    }

    //RG: Store all the registered airlines in a mapping: Map address airlineAddress to struct Airline
    //
    mapping(address => Airline) private airlines;

    // Data structure to store individual passenger inforamtion
    struct Passenger {
        bool isInsured;
        address passengerAddress;
        bytes32 flightKey;
        uint256 premiumPaid;
        uint256 insuranceDisbursed;
    }

    // Mapping to store all the passengers with a key = passengerKey and value = Struct Passenger
    mapping(bytes32 => Passenger) private passengers;

    // Store all the keys of the passenger + flight combination who paid for insurance for a particular flight
    bytes32[] private passengerKeys;


    //RG: setting up security of this contract by allowing the owner to set which addresses including contract addresses can access this contract functions
    //RG: Store address with a corresponding mapping value = 1 for authorized addresses which can call the functions of this contract
    mapping(address => uint256) authorizedContracts;

    /********************************************************************************************/
    /*                                       EVENT DEFINITIONS                                  */
    /********************************************************************************************/

    // Event fired when the data contract runs out of money to make insurance payments to "passenger" address
    event OutofBalance(address passenger, string result);


    /**
    * @dev Constructor
    *      The deploying account becomes contractOwner
    *      address airlineAddress: first airline to be registered when this contract is first deployed
    *      string airlineName: Name of the airlines being registered
    */
    constructor
                                (address airlineAddress,
                                string memory airlineName
                                )
                                public
    {
        // store the address of the contract owner who first deployed this contract
        contractOwner = msg.sender;
        // Register the first airline at contract deployment to the Blockchain
        registerAirline(airlineAddress, airlineName);

    }

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
    modifier requireIsOperational()
    {
        require(operational, "Contract is not operational");
        _;  // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
    * @dev Modifier that requires the "ContractOwner" account to be the function caller
    */
    modifier requireContractOwner()
    {
        require(msg.sender == contractOwner, "Caller not contract owner");
        _;
    }

    /**
    *RG
    * @dev Modifier that requires the caller of the function is authorized address to access data contract functions
    * The owner of the contract is always allowed to execute any function of this contract.
    */
    modifier requireAuthorizedContract()
    {
        require((authorizedContracts[msg.sender] == 1||msg.sender == contractOwner), "Caller is not Authorized to access data");
        _;
    }


    /********************************************************************************************/
    /*                                       UTILITY FUNCTIONS                                  */
    /********************************************************************************************/

    /**
    * @dev Get operating status of contract
    *
    * @return A bool that is the current operating status
    * No modifiers to restrict the access of this function so anyone can call this function
    */
    //RG: Changed the function to "external" visibility
    // This function is expected to be called only from outside of this contract. We alreay have the modifier requireIsOperational() for using inside of this contract
    // It is just a getter function. The variable "operational" was declared private so we need a getter function to access it's value from outside
    function isOperational()
                            external
                            view
                            returns(bool)
    {
        return operational;
    }


    /**
    * @dev Sets contract operations on/off by setting the boolean variable "operational" true or false
    *
    * When variable "operational" is set to false, all state changing transactions except for this one will fail
    * The lockup of the functions is enabled using the requireOperational() modifier on all the functions
    * Only owner can call this function for security
    */
    function setOperatingStatus
                            (
                                bool mode
                            )
                            external
                            requireContractOwner
    {
        operational = mode;
    }

    /********************************************************************************************/
    /*                                     SMART CONTRACT FUNCTIONS                             */
    /********************************************************************************************/

    /**
    * RG
    * @dev Add the contract address to mapping authorizedCotnracts to track authorized callers of this data contract
    * The contract owner will add the FlightSuretyApp contract address as an approved address.
    * This will give the app contract access to the functions of this data contract
     */
     function authorizeContract(address authorizedAddress) external requireIsOperational requireContractOwner {
         authorizedContracts[authorizedAddress] = 1;
     }

    /**
    *
    * @dev delete the contract address from mapping authorizedContracts to deauthorized callers of this data contract
    */
     function deAuthorizeContract(address authorizedAddress) external requireIsOperational requireContractOwner {
         delete authorizedContracts[authorizedAddress];
     }

    //Added this function to test addition of authorized contract addresses is working properly

    function isAuthorizedContract(address contractAddress) public view requireIsOperational returns(uint256)
    {
        if(authorizedContracts[contractAddress] == 1) {
            return 1;
        }
        else {
            return 0;
        }
    }

   /**
    * @dev Register a new airline and store the airline information to the blockchain in the mapping "airlines"
    *      Can only be called from FlightSuretyApp contract using the require modifier
    *
    */
    function registerAirline
                            (address airlineAddress,
                            string memory airlineName
                            )
                            public
                            requireAuthorizedContract requireIsOperational
    {
        airlines[airlineAddress].name = airlineName;
        airlines[airlineAddress].isApproved = false;
        airlines[airlineAddress].airlineAddress = airlineAddress;
        airlineCounter = airlineCounter.add(1);
        airlines[airlineAddress].serialNumber = airlineCounter;
        if(airlineCounter == 1) {
            airlines[airlineAddress].isFirst = true;
        }
        else {
            airlines[airlineAddress].isFirst = false;
        }
    }

// function to retrieve the mapping "airlines" to view the data stored on the blockchain for a particular
// registered airline.
    function airlineInfoReturn(address airlineAddress) external view returns
    (
        string memory airlineName,
        address airlineAddress1,
        bool isApproved,
        bool isFirst,
        uint256 serialNumber
    )
    {
        return
        (
            airlines[airlineAddress].name,
            airlines[airlineAddress].airlineAddress,
            airlines[airlineAddress].isApproved,
            airlines[airlineAddress].isFirst,
            airlines[airlineAddress].serialNumber
        );
    }

// function getAirlineName: Getter function to obtain name of the airline
    function getAirlineName(address airlineAddress) external view returns(string memory airlineName) {
        return airlines[airlineAddress].name;
    }

// function getAirlineStatus: Getter function to obtain approval status of the airline
    function getAirlineStatus(address airlineAddress) external view returns(bool) {
        return airlines[airlineAddress].isApproved;
    }


//  Getter function to check if a particular airline was already registered.
    function isAirlineRegistered(address airline) public view returns(bool) {
        if(airlines[airline].airlineAddress == airline) {
            return true;
        }
        else {return false;}
    }

// function approveAirline(): Add airline to the approved list once they pay 10 ether to participate

    function approveAirline(address airlineAddress) external payable requireIsOperational requireAuthorizedContract
    {
        airlines[airlineAddress].isApproved = true;
        uint256 valueSent = msg.value;
        insuranceBalance = insuranceBalance.add(valueSent);
    }

//  Getter function to check if a particular airline was already approved to participate in insurance pool.
    function isAirlineApproved(address airline) public view returns(bool) {
        return airlines[airline].isApproved;
    }


//function getInsuranceBalance(): Getter function to retrieve value stored in the contract

    function getInsuranceBalance() external view returns(uint256) {
       return address(this).balance;
       // return insuranceBalance;
    }


// function registerFlight(): Registers a flight if the airline is an approved airline
    function registerFlight(string memory flight, address airline, uint256 timestamp)
                            public
                            requireAuthorizedContract requireIsOperational
    {
        bytes32 key = keccak256(abi.encodePacked(flight, airline, timestamp));
        flights[key].isRegistered = true;
        flights[key].flight = flight;
        flights[key].airline = airline;
        flights[key].timestamp = timestamp;
        flights[key].key = key;
    }

// function to retrieve the mapping "flights" to view the data stored on the blockchain for a particular
// registered Flight.
    function flightInfoReturn(string memory flight, address airline, uint256 timestamp) public view returns
    (
        bool isRegistered,
        string memory flightName,
        address airlineAddress,
        uint256 flightTimestamp,
        bytes32 key
    )
    {
        bytes32 flightKey = keccak256(abi.encodePacked(flight, airline, timestamp));
        return
        (
            flights[flightKey].isRegistered,
            flights[flightKey].flight,
            flights[flightKey].airline,
            flights[flightKey].timestamp,
            flights[flightKey].key
        );
    }

/**
*   @dev Function to check to if the given flight was registered by the airline
 */
    function isFlightRegistered(bytes32 flightKey) external view returns(bool) {
        return flights[flightKey].isRegistered;
    }


/**
*   @dev Function to check to if the passenger already bought insurance for this flight
 */
    function isPassengerInsured(bytes32 passengerKey) external view returns(bool) {
        return passengers[passengerKey].isInsured;
    }



/**
*   @dev Function to let passenger buy insurance and store the money into this contract and also store data
*   of the passenger into a data structure
 */

    function buyFlightInsurance(bytes32 flightKey, bytes32 passengerKey, address passengerAdd) external payable
            requireIsOperational requireAuthorizedContract
    {
        uint256 valueSent = msg.value;
        insuranceBalance = insuranceBalance.add(valueSent);
        passengers[passengerKey].isInsured = true;
        passengers[passengerKey].passengerAddress = passengerAdd;
        passengers[passengerKey].flightKey = flightKey;
        passengers[passengerKey].premiumPaid = msg.value;
        passengerKeys.push(passengerKey);

    }

/**
*   @dev Function to obtain the insurance premium passengers[0] paid and is stored on the blockchain
 */
    function getPassengerPayment(string memory flight, address airline, uint256 timestamp) public view returns(uint256) {
        bytes32 passengerKey = keccak256(abi.encodePacked(flight, airline, timestamp, msg.sender));
        return passengers[passengerKey].premiumPaid;
    }

/**
*   @dev Function to obtain all the passengerKeys stored on blockchain
*/
    function getPassengerKeys() public view returns(bytes32[] memory) {
        return passengerKeys;
    }

/**
*   @dev Function to credit insurance payments to all eligible passengers whose flights got delayed
*/
    function payInsurance(bytes32 flightKey) external requireAuthorizedContract requireIsOperational {
        for(uint i=0; i<passengerKeys.length; i++) {
            bytes32 passengerKey = passengerKeys[i];
            if(passengers[passengerKey].flightKey == flightKey) {
                uint256 premiumPaid = passengers[passengerKey].premiumPaid;
                uint256 amountOwed = premiumPaid.mul(3).div(2);
                if(address(this).balance > amountOwed) {
                    passengers[passengerKey].insuranceDisbursed = amountOwed;
                }
                else {
                    string memory result = 'Insurance Contract on Blockchain is out of funds';
                    address passengerUnpaid = passengers[passengerKey].passengerAddress;
                    emit OutofBalance(passengerUnpaid, result);
                }
            }
        }
    }

/**
*   @dev Function to obtain the insurance amount a particular "passenger" was paid due to delayed flight
*/
    function getInsurancePaymentInfo(string memory flight, address airline, uint256 timestamp, address passenger) public view returns(uint256) {
        bytes32 passengerKey = keccak256(abi.encodePacked(flight, airline, timestamp, passenger));
        return passengers[passengerKey].insuranceDisbursed;
    }


/**
*   @dev Function to withdraw passenger credit balance
*/
    function passengerCreditWithdraw(bytes32 passengerKey, address passenger) external payable requireAuthorizedContract requireIsOperational
    {
        require(passengers[passengerKey].isInsured == true, 'Passenger was not insured - Money cannot be withdrawn');
        require(passengers[passengerKey].passengerAddress == passenger,'Passenger was not insured and cannot withdraw money');
        uint256 creditAmount = passengers[passengerKey].insuranceDisbursed;
        passengers[passengerKey].insuranceDisbursed = 0;
        require(address(this).balance > creditAmount, 'Data contract does not have sufficient funds - Cannot withdraw money');
        passengers[passengerKey].isInsured = false;
        passenger.transfer(creditAmount);

    }



    /**
    * @dev Fallback function for funding smart contract.
    *
    */
    function()
                            external
                            payable
    {
    }


}
