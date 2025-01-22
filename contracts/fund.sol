// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Fund {
    address private owner;
    bool private paused;
    uint256 public CONTRIBUTION_COMMISSION_RATE = 490;
    uint256 public TRANSACTION_COMMISSION_RATE = 290;

    enum ProjectStatus {
        Active,
        Funded,
        Failed
    }

    struct Milestone {
        uint milestone_sum;
        string milestone_description;
    }

    struct Contributor {
        address contributor_address;
        uint contribution;
    }

    struct Project {
        string project_name;
        string project_description;
        address project_creator;
        uint256 final_goal;
        uint256 funded;
        uint256 deadline;
        ProjectStatus projectStatus;
        bool exist;
    }

    mapping(address => bytes32[]) users_projects;
    mapping(address => uint) users_withdraw;

    mapping(bytes32 => Milestone[]) projects_milestones;
    mapping(bytes32 => Contributor[]) projects_contributors;
    mapping(bytes32 => Project) projects;

    bytes32[] projects_list;

    fallback() external payable { }
    receive() external payable { }

    constructor() {
        owner = msg.sender;
    }

    event ProjectCreated(bytes32 projectId, string project_name, string description, address creator, uint256 final_goal, uint256 deadline);
    event ContributionMade(bytes32 projectId, address contributor, uint256 amount);
    event FundsWithdrawn(bytes32 projectId, address creator, uint256 amount);
    event RefundIssued(bytes32 projectId, address contributor, uint256 amount);
    event PlatformFeeUpdated(uint256 newFee);
    event ProjectDescriptionUpdated(bytes32 projectId, string newDescription);
    event ProjectStatusUpdated(bytes32 projectID, ProjectStatus newStatus);

    modifier whenNotPaused() {
        require(!paused, "Contract is paused");
        _; 
    }

    modifier whenPaused() {
        require(paused, "Contract is not paused");
        _; 
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not the owner");
        _; 
    }

    modifier onlyCreator(bytes32 projectID) {
        require(idSearch(users_projects[msg.sender], projectID) != -1, "This user is not creator of this project");
        _;
    }

    modifier onlyForProjectCreator(bytes32 projectID) {
        require(msg.sender == getProjectCreator(projectID), "This user isn't creator of this project");
        _;
    }

    modifier projectExist(bytes32 projectID) {
        require(projectExists(projectID), "Project with this ID doesn't exist");
        _;
    }

    modifier projectActive(bytes32 projectID) {
        require(projectIsActive(projectID) == ProjectStatus.Active, "Project isn't active");
        _;
    }

    function projectIsActive(bytes32 projectId) public view returns (ProjectStatus) {
        return projects[projectId].projectStatus;
    }

    function getProjectCreator(bytes32 projectId) public view returns (address) {
        return projects[projectId].project_creator;
    }

    function projectExists(bytes32 projectID) public view returns (bool) {
        return projects[projectID].exist;
    }

    function quickSort(bytes32[] memory arr) public pure returns (bytes32[] memory) {
        if (arr.length <= 1) {
            return arr;
        }

        uint256[] memory stack = new uint256[](arr.length * 2);
        uint256 top = 0;

        stack[top++] = 0;
        stack[top++] = arr.length - 1;

        while (top > 0) {
            uint256 high = stack[--top];
            uint256 low = stack[--top];

            uint256 pivotIndex = partition(arr, low, high);

            if (pivotIndex > 0 && pivotIndex - 1 > low) {
                stack[top++] = low;
                stack[top++] = pivotIndex - 1;
            }

            if (pivotIndex + 1 < high) {
                stack[top++] = pivotIndex + 1;
                stack[top++] = high;
            }
        }

        return arr;
    }

    function partition(bytes32[] memory arr, uint256 low, uint256 high) internal pure returns (uint256) {
        bytes32 pivot = arr[high];
        uint256 i = low;

        for (uint256 j = low; j < high; j++) {
            if (arr[j] <= pivot) {
                (arr[i], arr[j]) = (arr[j], arr[i]);
                i++;
            }
        }

        (arr[i], arr[high]) = (arr[high], arr[i]);
        return i;
    }

    function idSearch(bytes32[] memory array, bytes32 target) public pure returns (int256) {
        int256 left = 0;
        int256 right = int256(array.length) - 1;

        while (left <= right) {
            int256 mid = left + (right - left) / 2;
            bytes32 midValue = array[uint256(mid)];

            if (midValue == target) {
                return mid; 
            } else if (midValue < target) {
                left = mid + 1;
            } else {
                right = mid - 1;
            }
        }

        return -1;
    }

    function pause() public whenNotPaused onlyOwner {
        paused = true;
    }

    function unpause() public whenPaused onlyOwner {
        paused = false;
    }

    function setContributionFee(uint256 fee) public onlyOwner {
        CONTRIBUTION_COMMISSION_RATE = fee;
    }

    function setTransactionFee(uint256 fee) public onlyOwner {
        TRANSACTION_COMMISSION_RATE = fee;
    }

    function getContributionFee() public view returns (uint256) {
        return CONTRIBUTION_COMMISSION_RATE;
    }

    function getTransactionFee() public view returns (uint256) {
        return TRANSACTION_COMMISSION_RATE;
    }

    function createProject(string memory name, string memory description, uint goal, uint deadline) public {
        bytes32 id = keccak256(abi.encodePacked(name, description, block.timestamp, msg.sender));
        Project memory newProject;
        newProject.project_name = name;
        newProject.project_description = description;
        newProject.project_creator = msg.sender;
        newProject.final_goal = goal;
        newProject.funded = 0;
        newProject.deadline = deadline;
        newProject.projectStatus = ProjectStatus.Active;
        newProject.exist = true;

        projects[id] = newProject;

        users_projects[msg.sender].push(id);

        projects_list.push(id);

        quickSort(users_projects[msg.sender]);

        emit ProjectCreated(id, name, description, msg.sender, goal, deadline);
    }

    function getProjectDetails(bytes32 projectID) public view returns (string memory, string memory, address, uint256, uint256, uint256, ProjectStatus) {
        Project storage project = projects[projectID];
        return (
            project.project_name,
            project.project_description,
            project.project_creator,
            project.final_goal,
            project.funded,
            project.deadline,
            project.projectStatus
        );
    }

    function setProjectDescription(bytes32 projectID, string memory newDescription) public onlyCreator(projectID) projectActive(projectID) {
        projects[projectID].project_description = newDescription;
        emit ProjectDescriptionUpdated(projectID, newDescription);
    }

    function setMilestone(bytes32 projectID, uint milestoneSum, string memory milestoneDescription) public onlyCreator(projectID) projectActive(projectID) {
        projects_milestones[projectID].push(Milestone({
            milestone_sum: milestoneSum,
            milestone_description: milestoneDescription
        }));
    }

    function getMilestones(bytes32 projectID) public view returns (Milestone[] memory) {
        return projects_milestones[projectID];
    }

    function getProjectStatus(bytes32 projectID) public view returns (ProjectStatus) {
        return projects[projectID].projectStatus;
    }

    function getAmountOfProjects() public view returns (uint256) {
        return projects_list.length;
    }

    function getUserProjects() public view returns (bytes32[] memory) {
        return users_projects[msg.sender];
    }

    function binarySearchContributor(bytes32 projectId, address targetAddress) public view returns (uint256 index, bool found) {
        Contributor[] storage arr = projects_contributors[projectId];
        uint256 low = 0;

        if (arr.length == 0) {
            return (0, false);
        }

        uint256 high = arr.length - 1;

        while (low <= high) {
            uint256 mid = low + (high - low) / 2;
            if (arr[mid].contributor_address == targetAddress) {
                return (mid, true);
            } else if (arr[mid].contributor_address < targetAddress) {
                low = mid + 1;
            } else {
                if (mid == 0) {
                    break;
                }
                high = mid - 1;
            }
        }
        return (0, false);
    }

    function fundProject(bytes32 projectID) public payable {
        require(projectExists(projectID), "Project does not exist");
        require(projectIsActive(projectID) == ProjectStatus.Active, "Project isn't active");
        require(msg.value > 0, "Contribution must be greater than zero");

        (uint256 contributorIndex, bool found) = binarySearchContributor(projectID, msg.sender);
        if (!found) {
            projects_contributors[projectID].push(Contributor({
                contributor_address: msg.sender,
                contribution: msg.value
            }));
        } else {
            projects_contributors[projectID][contributorIndex].contribution += msg.value;
        }

        projects[projectID].funded += msg.value;

        emit ContributionMade(projectID, msg.sender, msg.value);
    }

    function getUserContribution(bytes32 projectID) public view returns (uint256) {
        (uint256 contributorIndex, bool found) = binarySearchContributor(projectID, msg.sender);
        if (!found) {
            return 0;
        } else {
            return projects_contributors[projectID][contributorIndex].contribution;
        }
    }

    function makeRefund(bytes32 projectID) public {
        require(projectExists(projectID), "Project does not exist");
        ProjectStatus projectStatus = getProjectStatus(projectID);
        require(projectStatus == ProjectStatus.Failed, "Project isn't failed");

        Contributor[] storage contributorsArray = projects_contributors[projectID];
        for (uint256 i = 0; i < contributorsArray.length; i++) {
            address contributorAddress = contributorsArray[i].contributor_address;
            uint256 amountToWithdraw = contributorsArray[i].contribution;

            users_withdraw[contributorAddress] += amountToWithdraw;

            emit RefundIssued(projectID, contributorAddress, amountToWithdraw);
        }
    }

    function sendFunds(bytes32 projectID) public {
        require(projectExists(projectID), "Project does not exist");
        require(msg.sender == getProjectCreator(projectID), "Only project creator can send funds");
        require(projectIsActive(projectID) == ProjectStatus.Funded, "Project is not funded");

        address payable to = payable(getProjectCreator(projectID));
        uint256 amountToSend = projects[projectID].funded;

        projects[projectID].funded = 0;

        to.transfer(amountToSend);

        emit FundsWithdrawn(projectID, to, amountToSend);
    }

    function checkIfFundingComplete(bytes32 projectID) public {
    require(projectExists(projectID), "Project does not exist");
    Project storage project = projects[projectID];
    require(project.projectStatus == ProjectStatus.Active, "Project is not active");


    if (block.timestamp >= project.deadline) {
        if (project.funded >= project.final_goal) {

            project.projectStatus = ProjectStatus.Funded;
            emit ProjectStatusUpdated(projectID, ProjectStatus.Funded);

            sendFunds(projectID);
        } else {

            project.projectStatus = ProjectStatus.Failed;
            emit ProjectStatusUpdated(projectID, ProjectStatus.Funded);

            makeRefund(projectID);
        }
    } else {
        revert("Funding period is not over yet");
    }
}


    function withdraw() public {
        uint256 amountToWithdraw = users_withdraw[msg.sender];
        require(amountToWithdraw > 0, "Nothing to withdraw");
        users_withdraw[msg.sender] = 0;
        payable(msg.sender).transfer(amountToWithdraw);
    }
}
