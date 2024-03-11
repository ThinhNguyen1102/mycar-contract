// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract MyCar is Ownable, AccessControl {
	bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

	enum CarContractStatus {
		APPROVED,
		STARTED,
		ENDED,
		CANCELED
	}

	struct CarContract {
		uint contract_id;
		string owner_email;
		string renter_email;
		uint rental_price_per_day;
		uint over_limit_fee;
		uint over_time_fee;
		uint cleaning_fee;
		uint deodorization_fee;
		uint num_of_days;
		uint start_date;
		uint end_date;
		string car_model;
		string car_plate;
		CarContractStatus status;
		uint created_at;
	}

	mapping(uint => CarContract) private carContractList;

	uint[] private carContractIds;

	constructor() {
		_setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
		_setupRole(MANAGER_ROLE, msg.sender);
	}

	function createContract(
		uint contract_id,
		string memory owner_email,
		string memory renter_email,
		uint rental_price_per_day,
		uint over_limit_fee,
		uint over_time_fee,
		uint cleaning_fee,
		uint deodorization_fee,
		uint num_of_days,
		uint start_date,
		uint end_date,
		string memory car_model,
		string memory car_plate
	) public onlyManager {
		require(carContractList[contract_id].contract_id == 0, "Contract ID already exists");
		require(rental_price_per_day > 0, "Rental price per day must be greater than 0");
		require(num_of_days > 0, "Number of days must be greater than 0");
		require(start_date > 0, "Start date must be greater than 0");
		require(end_date > 0, "End date must be greater than 0");
		require(start_date < end_date, "Start date must be less than end date");
		require(bytes(owner_email).length > 0, "Owner email must not be empty");
		require(bytes(renter_email).length > 0, "Renter email must not be empty");
		require(bytes(car_model).length > 0, "Car model must not be empty");
		require(bytes(car_plate).length > 0, "Car plate must not be empty");

		carContractList[contract_id] = CarContract(
			contract_id,
			owner_email,
			renter_email,
			rental_price_per_day,
			over_limit_fee,
			over_time_fee,
			cleaning_fee,
			deodorization_fee,
			num_of_days,
			start_date,
			end_date,
			car_model,
			car_plate,
			CarContractStatus.APPROVED,
			block.timestamp
		);
		carContractIds.push(contract_id);
	}

	function pay(
		uint contract_id,
		string memory email,
		uint amount
	) public payable returns (uint, string memory, uint, address) {
		require(contract_id > 0, "Contract ID must be greater than 0");
		require(bytes(email).length > 0, "Email must not be empty");
		require(msg.value == amount, "Amount must be equal to the value sent");

		return (contract_id, email, amount, msg.sender);
	}

	function refundOwnerRejected(uint contract_id, address renter_address, uint amount) public onlyManager {
		require(contract_id > 0, "Contract ID must be greater than 0");
		require(amount > 0, "Amount must be greater than 0");
		require(amount <= address(this).balance, "Amount must be less than or equal to the contract balance");

		payable(renter_address).transfer(amount);
	}

	function refundOwnerCanceled(uint contract_id, address renter_address) public onlyManager {
		require(contract_id > 0, "Contract ID must be greater than 0");
		require(carContractList[contract_id].contract_id > 0, "Contract does not exist");

		CarContract memory carContract = carContractList[contract_id];
		require(carContract.status == CarContractStatus.APPROVED, "Contract status must be approved");

		uint totalPrice = carContract.rental_price_per_day * carContract.num_of_days;
		require(
			address(this).balance >= (totalPrice * 4) / 3,
			"Contract balance must be greater than or equal to the total price"
		);

		payable(renter_address).transfer((totalPrice * 4) / 3);
		carContractList[contract_id].status = CarContractStatus.CANCELED;
	}

	function refundRenterCanceled(uint contract_id, address owner_address, address renter_address) public onlyManager {
		require(contract_id > 0, "Contract ID must be greater than 0");
		require(carContractList[contract_id].contract_id > 0, "Contract does not exist");

		CarContract memory carContract = carContractList[contract_id];
		require(carContract.status == CarContractStatus.APPROVED, "Contract status must be approved");
		uint totalPrice = carContract.rental_price_per_day * carContract.num_of_days;
		require(
			address(this).balance >= (totalPrice * 4) / 3,
			"Contract balance must be greater than or equal to the total price"
		);

		payable(renter_address).transfer((totalPrice * 2) / 3);
		payable(owner_address).transfer((totalPrice * 2) / 3);
		carContractList[contract_id].status = CarContractStatus.CANCELED;
	}

	function getCarContractWithId(uint contract_id) public view returns (CarContract memory) {
		return carContractList[contract_id];
	}

	function getCarContracts() public view returns (CarContract[] memory) {
		CarContract[] memory contracts = new CarContract[](carContractIds.length);
		for (uint i = 0; i < carContractIds.length; i++) {
			contracts[i] = carContractList[carContractIds[i]];
		}
		return contracts;
	}

	function withdrawAll() public onlyOwner {
		payable(owner()).transfer(address(this).balance);
	}

	modifier onlyManager() {
		require(owner() == _msgSender() || hasRole(MANAGER_ROLE, _msgSender()), "Payment: caller is not the manager");
		_;
	}
}
