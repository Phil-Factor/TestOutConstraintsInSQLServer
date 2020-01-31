# What is this code for?
This is the code for a way of testing out data in a SQL Server database before enabling constraints

There are two points in any build, test or deployment where you can get into difficulties with your data because you have duplicates, bad data or data that has lost its relational integrity : firstly, when you do a build, disable constraints temporarily and Load (BCP) in the data, secondly, when you synchronize with a version of the database that does more checking of the data.  If you have existing bad data, you need a way of fixing it. To do that, you need to know about the data that would fail the constraint tests that your constraints would use if they were enabled.

One aspect of DevOps teamwork involves a sort of remote running of test software. You as a developer devise the test, it is run by someone else under circumstances you can’t directly control, and you get back a report that gives you enough information to fix any problems that come up. It is curiously like the old Sybase technique of sending queries via email to be run, but without the scary surface-area exposure
This type of test should avoid throwing errors and should collect all the information you need to script out a solution. It should not add work for the person who runs the script.

We have to have very slightly different ways of testing Check constraints (bad data checks), Unique Constraints (duplicate checks) and Foreign Key constraints (relational integrity checks).  We can store the list of constraints from the source database as a JSON file, and we can take this list as a source and store the result of our tests in a JSON report file

To run all these tests in a flexible way that fits in with a wide range in mathods of deployment, I’ve devised a general-purpose data-driven  way of running these tests and reports in PowerShell. 

# Where is this explained
- [But the Database Worked in Development! Preventing Broken Constraints](https://www.red-gate.com/simple-talk/sql/database-devops-sql/but-the-database-worked-in-development-preventing-broken-constraints/)
- But the Database Worked in Development! Preventing Duplicate rows
- But the Database Worked in Development! Preventing loss of referential integrity


 
