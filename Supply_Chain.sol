// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;

/**
@title Ownable is a Supercontract (parent) to the ItemManager.
The purpose of this contract is to manage ownership of an Item.
*/
contract Ownable{
    address payable _owner;

    /** Constructor to set the owner to the deployer of the contract. */
    constructor() public {
        _owner = msg.sender;
    }
    /** 
    Modifier to ensure that only the owner can execute certain functions.
    @dev This modifier is used in the functions createItem() and triggerDelivery()
    in the Subcontract (child).
    */
    modifier onlyOwner(){
        require(isOwner(),"You are not the owner");
        _;
    }
    /** 
    Function to check if the caller is the owner.
    @return bool - returns true if the caller is the owner.
    */
    function isOwner() public view returns(bool){
        return (msg.sender == _owner);
    }
}

/**
@title Item contract is representing an item in a supply chain.
@dev Used as a type object in ItemManager.
*/
contract Item {
    uint public priceInWei;
    uint public pricePaid;
    uint public index;
    ItemManager parentContract;

    /** Constructor to initialize item details and set the parent contract */
    constructor(ItemManager _parentContract, uint _priceInWei, uint _index) public {
        priceInWei = _priceInWei;
        index = _index;
        parentContract = _parentContract;
    }

    /** Receive function to handle payments when Ether is sent to the contract. */
    receive() external payable {
        require(pricePaid == 0, "Item is paid already");
        require(priceInWei == msg.value, "Only full payments allowed");
        pricePaid += msg.value;
        (bool success, ) = address(parentContract).call.value(msg.value)(abi.encodeWithSignature("triggerPayment(uint256)",index));
        require(success, "The transaction was not successful, canceling");
    }
    /**
    Fallback function to handle any unexpected Ether sent to the contract.
    @dev This is a requirement of the Remix IDE. It can be removed once
    the contract is added to a project.
    */
    fallback() external {}
}

/**
ItemManager contract managing the supply chain.
@dev This contract is Subcontract of Ownable.
*/
contract ItemManager is Ownable{
    // This enum is used to represent different states of the supply chain.
    enum SupplyChainState{Created, Paid, Delivered}
    
    // Struct to represent an item in the supply chain.
    struct S_Item {
        Item _item;
        string _identifier;
        uint _itemPrice;
        ItemManager.SupplyChainState _state;

    }
    // Mapping to store items by their index.
    mapping(uint => S_Item) public items;
    uint itemIndex;

    //Even is emitted on each supply chain step.
    event SupplyChainStep(uint _itemIdex, uint _step, address _itemAddress);

    /**
    Function to create a new item in the supply chain.
    @notice This function has the onlyOwner modifier from the Ownable contract.
    @param _identifier - this would be a unique item number.
    @param _itemPrice - this is the item price.
    */
    function createItem(string memory _identifier, uint _itemPrice) public onlyOwner {
        
        //Initialising new Item and setting the state to Created.
        Item item = new Item(this, _itemPrice, itemIndex);
        items[itemIndex]._item = item;
        items[itemIndex]._identifier = _identifier;
        items[itemIndex]._itemPrice = _itemPrice;
        items[itemIndex]._state = SupplyChainState.Created;
        
        // Emitting an event to indicate the creation of a new item.
        emit SupplyChainStep (itemIndex, uint(items[itemIndex]._state), address(item));
        itemIndex++;
    }

    /**
    Function to trigger payment for a specific item.
    @notice This is a payable function.
    @param _itemIndex - this is the index of the item in the array.
    */
    function triggerPayment (uint _itemIndex) public payable {
        require(items[_itemIndex]._itemPrice == msg.value, "Only full payments accepted");
        require(items[itemIndex]._state == SupplyChainState.Created, "Item is further in the chain");
        
        //Updating the item's state to paid.
        items[_itemIndex]._state = SupplyChainState.Paid;

        // Emit an event to indicate tha payment for the item.
        emit SupplyChainStep (_itemIndex, uint(items[_itemIndex]._state), address(items[_itemIndex]._item));
    }

    /**
    Function to trigger delivery for a specific item.
    @notice This function has the onlyOwner modifier from the Ownable contract.
    @param _itemIndex - this is the index of the item in the array.
    */
    function triggerDelivery(uint _itemIndex) public onlyOwner{
        require(items[_itemIndex]._state == SupplyChainState.Paid, "Item is further in the chain");
        
        //Update the item's state on Delivered.
        items[_itemIndex]._state = SupplyChainState.Delivered;

        //Emit an event to indicate the delivery of the item.
        emit SupplyChainStep(_itemIndex, uint(items[_itemIndex]._state), address(items[_itemIndex]._item));
    }
}