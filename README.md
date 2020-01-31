# What is this code for?
This is the code for a way of testing out data in a SQL Server database before enabling constraints

Even if your source and target databases have the same table names and columns, there is no guarantee that you can copy the data from one to the other successfully. If you are loading data from a different source such as an external application then all bets are off. Why is this? Well, it is due to  constraints in the target database  picking up duplicates, bad data and problems with referential integrity. These have to be fixed, otherwise you will always face a  performance deficit. You will probably also suffer a lot worse from the data problems too.  It all gets worse if you, as a developer, don’t have direct access to the data, or you as an Ops person don’t have the time or expertise to do the job.

This code is designed to try to prevent this sort of problem from happening. It checks data against the constraints in the target database and gives you a list of the data that needs to be fixed before you enable constraints, or before you start an automated process such as an automated build. 

Several times in my professional life, I’ve had to start an automated build before leaving work in the evening and hoping that, by the morning, the build process is finished. Almost all the time was spent loading the data.  If the build is broken then  things can be a bit tense when the team work out how to explain a day’s delay in a release. I’d have given a lot for this code, because I could have then built the new release without its data, copied out the constraint information, tested it on a previous version of the database and got a report of any likely problems.

There are two points in any build, test or deployment where you can get into difficulties with your data because you have duplicates, bad data or data that has lost its relational integrity : firstly, when you do a build, disable constraints temporarily and Load (BCP) in the data, secondly, when you synchronize with a version of the database that does more checking of the data.  If you have existing bad data, you need a way of fixing it. To do that, you need to know about the data that would fail the constraint tests that your constraints would use if they were enabled.

One aspect of DevOps teamwork involves a sort of remote running of test software. You as a developer devise the test, it is run by someone else under circumstances you can’t directly control, and you get back a report that gives you enough information to fix any problems that come up. It is curiously like the old Sybase technique of sending queries via email to be run, but without the scary surface-area exposure
This type of test should avoid throwing errors and should collect all the information you need to script out a solution. It should not add work for the person who runs the script.

We have to have very slightly different ways of testing Check constraints (bad data checks), Unique Constraints (duplicate checks) and Foreign Key constraints (relational integrity checks).  We can store the list of constraints from the source database as a JSON file, and we can take this list as a source and store the result of our tests in a JSON report file

To run all these tests in a flexible way that fits in with a wide range in mathods of deployment, I’ve devised a general-purpose data-driven  way of running these tests and reports in PowerShell. 

# Where is this explained
- [But the Database Worked in Development! Preventing Broken Constraints](https://www.red-gate.com/simple-talk/sql/database-devops-sql/but-the-database-worked-in-development-preventing-broken-constraints/)
- But the Database Worked in Development! Preventing Duplicate rows
- But the Database Worked in Development! Preventing loss of referential integrity


 
