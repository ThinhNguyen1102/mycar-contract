// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract MyCar is Ownable, AccessControl {
	bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
	uint public refund_rate = 25;

	enum CarContractStatus {
		APPROVED,
		STARTED,
		ENDED,
		CANCELED
	}

	struct CarContract {
		uint contract_id;
		string owner_email;
		address owner_address;
		string renter_email;
		address renter_address;
		uint rental_price_per_day;
		uint mortgage;
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

	event PaymentReceived(uint contract_id, string email, uint amount, address sender);
	event CarContractCreated(
		uint contract_id,
		address owner_address,
		string owner_email,
		address renter_address,
		string renter_email
	);
	event CarContractStarted(uint contract_id);
	event CarContractEnded(uint contract_id);
	event CarContractRefundedOwnerRejected(uint contract_id, uint renter_amount);
	event CarContractRefundedOwnerCanceled(uint contract_id, uint renter_amount);
	event CarContractRefundedRenterCanceled(uint contract_id, uint renter_amount, uint owner_amount);
	event CarContractRefunded(uint contract_id, uint renter_amount, uint owner_amount);

	constructor() {
		_setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
		_setupRole(MANAGER_ROLE, msg.sender);
	}

	function createContract(
		uint contract_id,
		string memory owner_email,
		address owner_address,
		string memory renter_email,
		address renter_address,
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
		require(start_date < end_date, "Start date must be less than end date");
		require(start_date > (block.timestamp + 86400) * 1000, "Start date must be greater than current date");
		require(bytes(owner_email).length > 0, "Owner email must not be empty");
		require(bytes(renter_email).length > 0, "Renter email must not be empty");
		require(bytes(car_model).length > 0, "Car model must not be empty");
		require(bytes(car_plate).length > 0, "Car plate must not be empty");
		require(over_limit_fee < (rental_price_per_day * 1) / 5, "Over limit fee must be less than 20% of rental price");
		require(over_time_fee < (rental_price_per_day * 1) / 5, "Over time fee must be less than 20% of rental price");
		require(cleaning_fee < (rental_price_per_day * 1) / 5, "Cleaning fee must be less than 20% of rental price");
		require(
			deodorization_fee < (rental_price_per_day * 1) / 5,
			"Deodorization fee must be less than 20% of rental price"
		);

		carContractList[contract_id] = CarContract(
			contract_id,
			owner_email,
			owner_address,
			renter_email,
			renter_address,
			rental_price_per_day,
			0.1 ether,
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
			block.timestamp * 1000
		);
		carContractIds.push(contract_id);

		emit CarContractCreated(contract_id, owner_address, owner_email, renter_address, renter_email);
	}

	function pay(
		uint contract_id,
		string memory email,
		uint amount
	) public payable returns (uint, string memory, uint, address) {
		require(contract_id > 0, "Contract ID must be greater than 0");
		require(bytes(email).length > 0, "Email must not be empty");
		require(msg.value == amount, "Amount must be equal to the value sent");

		emit PaymentReceived(contract_id, email, amount, msg.sender);
		return (contract_id, email, amount, msg.sender);
	}

	function refundOwnerReject(uint contract_id, address renter_address, uint amount) public onlyManager {
		require(contract_id > 0, "Contract ID must be greater than 0");
		require(amount > 0, "Amount must be greater than 0");
		require(amount <= address(this).balance, "Amount must be less than or equal to the contract balance");

		payable(renter_address).transfer(amount);

		emit CarContractRefundedOwnerRejected(contract_id, amount);
	}

	function refundOwnerCancel(uint contract_id) public onlyManager {
		require(contract_id > 0, "Contract ID must be greater than 0");
		require(carContractList[contract_id].contract_id > 0, "Contract does not exist");

		CarContract memory carContract = carContractList[contract_id];
		require(carContract.status == CarContractStatus.APPROVED, "Contract status must be approved");

		uint totalPrice = carContract.rental_price_per_day * carContract.num_of_days;
		uint totalRefund = totalPrice + (totalPrice * refund_rate) / 100 + carContract.mortgage;
		require(address(this).balance >= totalRefund, "Contract balance must be greater than or equal to the total price");

		payable(carContract.renter_address).transfer(totalRefund);
		carContractList[contract_id].status = CarContractStatus.CANCELED;

		emit CarContractRefundedOwnerCanceled(contract_id, totalRefund);
	}

	function refundRenterCancel(uint contract_id) public onlyManager {
		require(contract_id > 0, "Contract ID must be greater than 0");
		require(carContractList[contract_id].contract_id > 0, "Contract does not exist");

		CarContract memory carContract = carContractList[contract_id];
		require(carContract.status == CarContractStatus.APPROVED, "Contract status must be approved");
		uint totalPrice = carContract.rental_price_per_day * carContract.num_of_days;
		uint totalRefund = totalPrice + (totalPrice * refund_rate) / 100 + carContract.mortgage;
		require(address(this).balance >= totalRefund, "Contract balance must be greater than or equal to the total price");

		uint renterRefund = (totalPrice * (100 - refund_rate)) / 100 + carContract.mortgage;
		uint ownerRefund = (totalPrice * refund_rate * 2) / 100;

		payable(carContract.renter_address).transfer(renterRefund);
		payable(carContract.owner_address).transfer(ownerRefund);
		carContractList[contract_id].status = CarContractStatus.CANCELED;

		emit CarContractRefundedRenterCanceled(contract_id, renterRefund, ownerRefund);
	}

	function refund(uint contract_id) public onlyManager {
		require(contract_id > 0, "Contract ID must be greater than 0");
		require(carContractList[contract_id].contract_id > 0, "Contract does not exist");

		CarContract memory carContract = carContractList[contract_id];
		require(carContract.status == CarContractStatus.APPROVED, "Contract status must be approved");
		uint totalPrice = carContract.rental_price_per_day * carContract.num_of_days;
		uint totalRefund = totalPrice + (totalPrice * refund_rate) / 100 + carContract.mortgage;
		require(address(this).balance >= totalRefund, "Contract balance must be greater than or equal to the total price");

		uint renterRefund = totalPrice + carContract.mortgage;
		uint ownerRefund = (totalPrice * refund_rate) / 100;

		payable(carContract.renter_address).transfer(renterRefund);
		payable(carContract.owner_address).transfer(ownerRefund);
		carContractList[contract_id].status = CarContractStatus.CANCELED;

		emit CarContractRefunded(contract_id, renterRefund, ownerRefund);
	}

	function startContract(uint contract_id) public onlyManager {
		require(contract_id > 0, "Contract ID must be greater than 0");
		require(carContractList[contract_id].contract_id > 0, "Contract does not exist");

		CarContract memory carContract = carContractList[contract_id];
		require(carContract.status == CarContractStatus.APPROVED, "Contract status must be approved");
		uint totalPrice = carContract.rental_price_per_day * carContract.num_of_days;

		payable(carContract.owner_address).transfer((totalPrice * 1) / 4);
		carContractList[contract_id].status = CarContractStatus.STARTED;

		emit CarContractStarted(contract_id);
	}

	function endContract(
		uint contract_id,
		bool is_over_limit,
		uint over_times,
		bool is_cleaning_fee,
		bool is_deodorization_fee
	) public onlyManager {
		require(contract_id > 0, "Contract ID must be greater than 0");
		require(carContractList[contract_id].contract_id > 0, "Contract does not exist");

		CarContract memory carContract = carContractList[contract_id];
		require(carContract.status == CarContractStatus.STARTED, "Contract status must be started");
		uint totalPrice = carContract.rental_price_per_day * carContract.num_of_days;
		uint surcharge;

		if (is_over_limit) {
			surcharge += carContract.over_limit_fee;
		}

		if (over_times > 0) {
			surcharge += carContract.over_time_fee * over_times;
		}

		if (is_cleaning_fee) {
			surcharge += carContract.cleaning_fee;
		}

		if (is_deodorization_fee) {
			surcharge += carContract.deodorization_fee;
		}

		payable(carContract.owner_address).transfer(totalPrice + surcharge);
		payable(carContract.renter_address).transfer(carContract.mortgage - surcharge);
		carContractList[contract_id].status = CarContractStatus.ENDED;

		emit CarContractEnded(contract_id);
	}

	function setRefundRate(uint rate) public onlyManager {
		require(rate > 0, "Rate must be greater than 0");
		require(rate < 30, "Rate must be less than 100");

		refund_rate = rate;
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
