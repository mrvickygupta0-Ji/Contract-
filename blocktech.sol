// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title BlockTeach
 * @dev A decentralized education platform smart contract
 * @author BlockTeach Development Team
 */
contract BlockTeach {
    
    // State variables
    address public owner;
    uint256 public totalCourses;
    uint256 public totalStudents;
    
    // Structs
    struct Course {
        uint256 courseId;
        string title;
        string description;
        address instructor;
        uint256 price;
        uint256 enrolledCount;
        bool isActive;
        uint256 createdAt;
    }
    
    struct Student {
        address studentAddress;
        string name;
        uint256[] enrolledCourses;
        uint256 totalCoursesCompleted;
        uint256 joinedAt;
    }
    
    struct Enrollment {
        uint256 courseId;
        address student;
        uint256 enrolledAt;
        bool isCompleted;
        uint8 rating;
    }
    
    // Mappings
    mapping(uint256 => Course) public courses;
    mapping(address => Student) public students;
    mapping(address => bool) public isRegisteredStudent;
    mapping(uint256 => mapping(address => Enrollment)) public enrollments;
    mapping(address => uint256) public instructorEarnings;
    
    // Events
    event CourseCreated(uint256 indexed courseId, string title, address indexed instructor, uint256 price);
    event StudentRegistered(address indexed student, string name);
    event CourseEnrolled(uint256 indexed courseId, address indexed student, uint256 amount);
    event CourseCompleted(uint256 indexed courseId, address indexed student, uint8 rating);
    event EarningsWithdrawn(address indexed instructor, uint256 amount);
    
    // Modifiers
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner can perform this action");
        _;
    }
    
    modifier onlyRegisteredStudent() {
        require(isRegisteredStudent[msg.sender], "Student must be registered");
        _;
    }
    
    modifier courseExists(uint256 _courseId) {
        require(_courseId > 0 && _courseId <= totalCourses, "Course does not exist");
        _;
    }
    
    // Constructor
    constructor() {
        owner = msg.sender;
        totalCourses = 0;
        totalStudents = 0;
    }
    
    /**
     * @dev Core Function 1: Create a new course
     * @param _title Course title
     * @param _description Course description
     * @param _price Course price in wei
     */
    function createCourse(
        string memory _title,
        string memory _description,
        uint256 _price
    ) external {
        require(bytes(_title).length > 0, "Course title cannot be empty");
        require(bytes(_description).length > 0, "Course description cannot be empty");
        require(_price > 0, "Course price must be greater than 0");
        
        totalCourses++;
        
        courses[totalCourses] = Course({
            courseId: totalCourses,
            title: _title,
            description: _description,
            instructor: msg.sender,
            price: _price,
            enrolledCount: 0,
            isActive: true,
            createdAt: block.timestamp
        });
        
        emit CourseCreated(totalCourses, _title, msg.sender, _price);
    }
    
    /**
     * @dev Core Function 2: Register as a student
     * @param _name Student's name
     */
    function registerStudent(string memory _name) external {
        require(!isRegisteredStudent[msg.sender], "Student already registered");
        require(bytes(_name).length > 0, "Student name cannot be empty");
        
        students[msg.sender] = Student({
            studentAddress: msg.sender,
            name: _name,
            enrolledCourses: new uint256[](0),
            totalCoursesCompleted: 0,
            joinedAt: block.timestamp
        });
        
        isRegisteredStudent[msg.sender] = true;
        totalStudents++;
        
        emit StudentRegistered(msg.sender, _name);
    }
    
    /**
     * @dev Core Function 3: Enroll in a course
     * @param _courseId ID of the course to enroll in
     */
    function enrollInCourse(uint256 _courseId) 
        external 
        payable 
        courseExists(_courseId) 
        onlyRegisteredStudent 
    {
        Course storage course = courses[_courseId];
        require(course.isActive, "Course is not active");
        require(msg.value >= course.price, "Insufficient payment");
        require(enrollments[_courseId][msg.sender].student == address(0), "Already enrolled in this course");
        
        // Create enrollment record
        enrollments[_courseId][msg.sender] = Enrollment({
            courseId: _courseId,
            student: msg.sender,
            enrolledAt: block.timestamp,
            isCompleted: false,
            rating: 0
        });
        
        // Update student's enrolled courses
        students[msg.sender].enrolledCourses.push(_courseId);
        
        // Update course enrolled count
        course.enrolledCount++;
        
        // Add earnings to instructor
        instructorEarnings[course.instructor] += course.price;
        
        // Refund excess payment
        if (msg.value > course.price) {
            payable(msg.sender).transfer(msg.value - course.price);
        }
        
        emit CourseEnrolled(_courseId, msg.sender, course.price);
    }
    
    // Additional utility functions
    
    /**
     * @dev Complete a course and provide rating
     * @param _courseId ID of the course to complete
     * @param _rating Rating from 1-5
     */
    function completeCourse(uint256 _courseId, uint8 _rating) 
        external 
        courseExists(_courseId) 
        onlyRegisteredStudent 
    {
        require(_rating >= 1 && _rating <= 5, "Rating must be between 1 and 5");
        require(enrollments[_courseId][msg.sender].student != address(0), "Not enrolled in this course");
        require(!enrollments[_courseId][msg.sender].isCompleted, "Course already completed");
        
        enrollments[_courseId][msg.sender].isCompleted = true;
        enrollments[_courseId][msg.sender].rating = _rating;
        
        students[msg.sender].totalCoursesCompleted++;
        
        emit CourseCompleted(_courseId, msg.sender, _rating);
    }
    
    /**
     * @dev Withdraw earnings (for instructors)
     */
    function withdrawEarnings() external {
        uint256 earnings = instructorEarnings[msg.sender];
        require(earnings > 0, "No earnings to withdraw");
        
        instructorEarnings[msg.sender] = 0;
        payable(msg.sender).transfer(earnings);
        
        emit EarningsWithdrawn(msg.sender, earnings);
    }
    
    /**
     * @dev Get student's enrolled courses
     * @param _student Student address
     */
    function getStudentCourses(address _student) external view returns (uint256[] memory) {
        return students[_student].enrolledCourses;
    }
    
    /**
     * @dev Get course details
     * @param _courseId Course ID
     */
    function getCourse(uint256 _courseId) external view courseExists(_courseId) returns (
        string memory title,
        string memory description,
        address instructor,
        uint256 price,
        uint256 enrolledCount,
        bool isActive
    ) {
        Course memory course = courses[_courseId];
        return (
            course.title,
            course.description,
            course.instructor,
            course.price,
            course.enrolledCount,
            course.isActive
        );
    }
    
    /**
     * @dev Toggle course active status (only course instructor)
     * @param _courseId Course ID
     */
    function toggleCourseStatus(uint256 _courseId) external courseExists(_courseId) {
        require(courses[_courseId].instructor == msg.sender, "Only course instructor can toggle status");
        courses[_courseId].isActive = !courses[_courseId].isActive;
    }
    
    /**
     * @dev Emergency withdrawal (only owner)
     */
    function emergencyWithdraw() external onlyOwner {
        payable(owner).transfer(address(this).balance);
    }
    
    // Fallback function
    receive() external payable {
        revert("Direct payments not accepted");
    }
}
