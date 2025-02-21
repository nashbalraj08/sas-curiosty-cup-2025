/*Import the dataset*/
options validvarname=v7;

/* Create a library named 'proj' */
LIBNAME proj "/home/u63781031/Curiosity Cup 2025";

/* Import CSV and store it in the 'proj' library */
PROC IMPORT DATAFILE="/home/u63781031/Curiosity Cup 2025/coursera_courses.xlsx" 
		OUT=proj.coursera_data DBMS=xlsx REPLACE;
	GETNAMES=YES;
RUN;

/*Dataset Overview*/
PROC CONTENTS DATA=proj.coursera_data;
	/*Access a library*/
RUN;

/*Numeric Descriptive Stats */
PROC MEANS DATA=proj.coursera_data N MEAN MEDIAN STD MIN MAX NMISS;
	VAR _NUMERIC_;
RUN;

/*Character Frequency Stats */
PROC FREQ DATA=proj.coursera_data NLEVELS;
	TABLES _CHARACTER_ / MISSING;
	ODS OUTPUT NLevels=CharSummary;
RUN;

/*Data Cleaning*/
/*Convert Character to Numeric and remove K: course_reviews*/
PROC SQL;
	SELECT DISTINCT course_reviews_num FROM proj.coursera_data;
QUIT;

/*K values included*/
DATA proj.coursera_data_cleaned;
	SET proj.coursera_data;
	course_reviews=INPUT(TRANWRD(LOWCASE(course_reviews_num), 'k', ''), 8.);

	/* Adjust Values: Multiply by 1000 if originally had 'k' */
	IF INDEX(LOWCASE(course_reviews_num), 'k') > 0 THEN
		course_reviews=course_reviews * 1000;
	DROP course_reviews_num;
RUN;

/*Numeric Descriptive Stats */
PROC MEANS DATA=proj.coursera_data_cleaned N MEAN MEDIAN STD MIN MAX NMISS;
	VAR _NUMERIC_;
RUN;

/*Handle Missing Values: Apply the 5% Rule removing a small portion won’t affect the analysis*/
/*Since course_rating (0.6%),course_reviews(0.65) and course_students_enrolled (4.1%) have missing values below 5%, we should drop the missing values.*/
/* Remove rows where course_rating,course_reviews or course_students_enrolled is missing */
DATA proj.coursera_data_cleaned;
	SET proj.coursera_data_cleaned;

	IF NOT MISSING(course_rating) AND NOT MISSING(course_students_enrolled) AND 
		NOT MISSING(course_reviews);
RUN;

PROC MEANS DATA=proj.coursera_data_cleaned N MEAN MEDIAN STD MIN MAX NMISS;
	VAR _NUMERIC_;
RUN;

/*Character Frequency Stats */
PROC FREQ DATA=proj.coursera_data_cleaned NLEVELS;
	TABLES _CHARACTER_ / MISSING;
	ODS OUTPUT NLevels=CharSummary;
RUN;

/*Only 1 missing value in description*/
/* Remove rows where course_desciption is missing */
DATA proj.coursera_data_cleaned;
	SET proj.coursera_data_cleaned;

	IF NOT MISSING(course_description);
RUN;

PROC FREQ DATA=proj.coursera_data_cleaned NLEVELS;
	TABLES _CHARACTER_ / MISSING;
	ODS OUTPUT NLevels=CharSummary;
RUN;

/*Identify Duplicates*/
PROC SORT DATA=proj.coursera_data_cleaned OUT=proj.duplicates_all NODUPKEY 
		DUPOUT=proj.duplicates_only;
	BY _ALL_;
RUN;

PROC PRINT DATA=proj.duplicates_only;
	TITLE "All Duplicate Records Based on All Columns";
RUN;

/*No duplicates across columns*/
/*Check Duplicates Based on Specific Columns*/
PROC SQL;
	CREATE TABLE duplicates_by_title AS SELECT *, COUNT(*) AS duplicate_count FROM 
		proj.coursera_data_cleaned GROUP BY course_title HAVING COUNT(*) > 1;
QUIT;

/*However, the duplicate records are actually from different organizations. We assume the course title
might be offered by different institutions with varying content, instructors, or teaching methods. This
makes them distinct. Therefore, we don't remove them but ensure they are distinct by appending the course
title and organization for the following 14 records*/
PROC SORT DATA=proj.coursera_data_cleaned;
	BY course_title;
RUN;

DATA proj.coursera_data_cleaned;
	SET proj.coursera_data_cleaned;
	BY course_title;
	RETAIN flag 0;

	/* Identify duplicate titles from different organizations */
	IF FIRST.course_title AND LAST.course_title THEN
		flag=0;
	ELSE
		flag=1;

	/* Append organization name only for duplicate titles */
	IF flag=1 THEN
		course_title=CATX(' - ', course_title, course_organization);
RUN;

PROC SQL;
	CREATE TABLE duplicates_by_title AS SELECT *, COUNT(*) AS duplicate_count FROM 
		proj.coursera_data_cleaned GROUP BY course_title HAVING COUNT(*) > 1;
QUIT;

/*Further Analysis for Google courses */
PROC SORT DATA=proj.coursera_data_cleaned;
	BY course_title;
RUN;

DATA proj.coursera_data_cleaned;
	SET proj.coursera_data_cleaned;
	BY course_title;
	RETAIN flag 0;

	/* Identify duplicate titles from different organizations */
	IF FIRST.course_title AND LAST.course_title THEN
		flag=0;
	ELSE
		flag=1;

	/* Append course review name only for duplicate titles in Google */
	IF flag=1 THEN
		course_title=CATX(' - ', course_title, course_organization, course_reviews);
RUN;

PROC SQL;
	CREATE TABLE duplicates_by_title AS SELECT *, COUNT(*) AS duplicate_count FROM 
		proj.coursera_data_cleaned GROUP BY course_title HAVING COUNT(*) > 1;
QUIT;

/*Feature Engineering

Retention Rate = (course_reviews_num / course_students_enrolled) * 100

*/
DATA proj.coursera_data_cleaned;
	SET proj.coursera_data_cleaned;

	IF course_students_enrolled > 0 THEN
		DO;
			retention_rate=(course_reviews / course_students_enrolled) * 100;

			/* Cap retention rate at 100% */
			IF retention_rate > 100 THEN
				retention_rate=100;
		END;
	ELSE
		retention_rate=.;	/* Assign missing value if division by zero */
	DROP flag;
RUN;

/*Numeric Descriptive Stats */
PROC MEANS DATA=proj.coursera_data_cleaned N MEAN MEDIAN STD MIN MAX NMISS;
	VAR _NUMERIC_;
RUN;

/*Character Frequency Stats */
PROC FREQ DATA=proj.coursera_data_cleaned NLEVELS;
	TABLES _CHARACTER_ / MISSING;
	ODS OUTPUT NLevels=CharSummary;
RUN;

/*Dataset Overview after cleanup*/
PROC CONTENTS DATA=proj.coursera_data_cleaned;
	/*Access a library*/
RUN;



/*Exploratory Analysis*/


/*Correlation Matrix*/
PROC CORR DATA=proj.coursera_data_cleaned OUTP=correlation_matrix NOPROB;
	VAR _NUMERIC_;
RUN;

//Identify Target Variable 
/* Histogram for retention rate */
PROC SGPLOT DATA=proj.coursera_data_cleaned;
	HISTOGRAM retention_rate / FILLATTRS=(COLOR=BLUE) TRANSPARENCY=0.3 BINWIDTH=10 
		SHOWBINS;
	DENSITY retention_rate/ TYPE=KERNEL;
	TITLE "Distribution of Retention Rate";
	XAXIS LABEL="Rentention Rates";
	YAXIS LABEL="Number of Courses";
RUN;

/* Box-and-Whisker Plot for retention rate */
PROC SGPLOT DATA=proj.coursera_data_cleaned;
	VBOX retention_rate / OUTLIERSATTRS=(COLOR=RED SYMBOL=PLUS);
	TITLE "Box-and-Whisker Plot of Retention Rate";
	YAXIS LABEL="Number of Courses" GRID;
	KEYLEGEND / TITLE=" Boxplot of Retention Rate with Highlighted Outliers";
RUN;

/* Histogram for course ratings */
PROC SGPLOT DATA=proj.coursera_data_cleaned;
	HISTOGRAM course_rating / FILLATTRS=(COLOR=BLUE) TRANSPARENCY=0.3 BINWIDTH=1 
		SHOWBINS;
	DENSITY course_rating / TYPE=KERNEL;
	TITLE "Distribution of Course Ratings";
	XAXIS LABEL="Course Rating" MIN=0 MAX=5;
	YAXIS LABEL="Number of Courses";
RUN;

/* Box-and-Whisker Plot for  course ratings  */
PROC SGPLOT DATA=proj.coursera_data_cleaned;
	VBOX course_rating / OUTLIERSATTRS=(COLOR=RED SYMBOL=PLUS);
	TITLE "Box-and-Whisker Plot of Course Rating";
	YAXIS LABEL="Course Rating" GRID;
	KEYLEGEND / TITLE="Boxplot of Course Rating with Highlighted Outliers";
RUN;

/*
Box-whisker diagram:
 *The median rating is approximately 4.8, indicating that most courses are rated highly.
 *Interquartile Range (IQR): The box (25th to 75th percentile) is narrow, between about 4.6 and 4.9, showing low rating variability.
 * There are several outliers below 4.0, with a few as low as 3.0, but these are rare.


Histogram:
 * The histogram shows a highly right-skewed distribution, with most courses rated between 4.5 and 5.0.
 * This suggests that ratings on the platform are highly favourable, which may indicate satisfied learners, effective courses, or potential rating inflation.

 */





/*Which courses have the highest and lowest rating scores?*/


PROC SQL OUTOBS=10;
	CREATE TABLE top_10_courses_rating_rate AS SELECT course_title, course_rating 
		FROM proj.coursera_data_cleaned ORDER BY course_rating DESC;
QUIT;

PROC SGPLOT DATA=top_10_courses_rating_rate;
	HBAR course_title / RESPONSE=course_rating DATALABEL FILLATTRS=(COLOR=BLUE) 
		CATEGORYORDER=RESPDESC;
	TITLE "Top 10 Courses by Rating Score";
	XAXIS LABEL="Rating Score(0-5)";
	YAXIS LABEL="Courses";
RUN;


PROC SQL OUTOBS=10;
	CREATE TABLE bottom_10_courses_rating_rate AS SELECT course_title, 
		course_rating FROM proj.coursera_data_cleaned ORDER BY course_rating ASC;
QUIT;

PROC SGPLOT DATA=bottom_10_courses_rating_rate;
	HBAR course_title / RESPONSE=course_rating FILLATTRS=(COLOR=BLUE) 
		CATEGORYORDER=RESPDESC;
	TITLE "Bottom 10 Courses by Rating Score";
	XAXIS LABEL="Rating Score(0-5)";
	YAXIS LABEL="Courses";
RUN;




/*Are top courses from Google?*/
PROC SQL OUTOBS=10;
	CREATE TABLE top_10_courses_rating_rate AS SELECT course_title,course_difficulty,course_time,course_skills,course_organization, course_rating 
		FROM proj.coursera_data_cleaned ORDER BY course_rating DESC;
QUIT;

/*Where are bottom courses from?*/
PROC SQL OUTOBS=10;
	CREATE TABLE bottom_10_courses_rating_rate AS SELECT course_title,course_difficulty,course_time,course_skills, course_rating  
		FROM proj.coursera_data_cleaned ORDER BY course_rating ASC;
QUIT;


/*Identify Top Skills in top 10 courses*/

/* Tokenize the Text Column into Words */
DATA word_tokens;
	SET bottom_10_courses_rating_rate;
	LENGTH skills $100;
	course_skills_clean=PRXCHANGE('s/[][(){}''"”“‘’`]+//i', -1, course_skills);

	/* Removes quotes, brackets */
	course_skills_clean=PRXCHANGE('s/^[^a-zA-Z0-9]+|[^a-zA-Z0-9]+$//', -1, 
		course_skills);

	/* Trim edges */
	course_skills_clean=TRANWRD(TRANWRD(TRANWRD(course_skills, "[", ""), "]", ""), 
		"'", "");

	/* Split course skills into words */
	DO i=1 TO COUNTW(course_skills_clean, ',');
		skill=STRIP(SCAN(course_skills_clean, i, ','));
		OUTPUT;
	END;
	DROP i;
RUN;

PROC SQL OUTOBS=10;
	CREATE TABLE skill_freq AS SELECT skill, COUNT(*) AS frequency FROM 
		word_tokens WHERE NOT MISSING(skill) /* Remove empty rows */
		GROUP BY skill ORDER BY frequency DESC;
QUIT;


PROC SGPLOT DATA=skill_freq;
	BUBBLE X=frequency Y=skill SIZE=frequency / TRANSPARENCY=0.5 DATALABEL=skill;
	XAXIS LABEL="Frequency" GRID;
	YAXIS DISPLAY=(NOLABEL);
	TITLE "Word Cloud Simulation for Bottom 10 Courses skills";
RUN;



/*Do shorter courses have higher rating scores than longer ones?*/

PROC SGPLOT DATA=proj.coursera_data_cleaned;
	VBOX course_rating / CATEGORY=course_time TRANSPARENCY=0.2 
		FILLATTRS=(COLOR=BLUE) OUTLIERSATTRS=(COLOR=RED SYMBOL=PLUS);
	XAXIS LABEL="Course Duration Category";
	YAXIS LABEL="Rating Score(0-5)";
	TITLE "Course Rating by Course Duration";
RUN;

/*Does course difficulty level (Beginner, Intermediate, Advanced) affect rating score?*/

PROC SGPLOT DATA=proj.coursera_data_cleaned;
	VBOX course_rating / CATEGORY=course_difficulty TRANSPARENCY=0.2 
		FILLATTRS=(COLOR=BLUE) OUTLIERSATTRS=(COLOR=RED SYMBOL=PLUS);
	XAXIS LABEL="Course Difficulty Level";
	YAXIS LABEL="Rating Score(0-5)";
	TITLE "Course Rating by Course Difficulty Level";
RUN;

/*Which organizations (e.g., Google, IBM) have the highest course rating score?
*/
/*Find top 10 organizations*/
PROC SQL OUTOBS=10;
	CREATE TABLE top_10_orgs AS SELECT course_organization, COUNT(*) AS 
		course_count FROM proj.coursera_data_cleaned GROUP BY course_organization 
		ORDER BY course_count DESC;
QUIT;


/* Bar Graph for Course Organization */
PROC SGPLOT DATA=top_10_orgs;
	VBAR course_organization / RESPONSE=course_count DATALABEL 
		FILLATTRS=(COLOR=BLUE) CATEGORYORDER=RESPDESC;
	TITLE "Top 10 Organizations";
	XAXIS LABEL="Organizations" VALUEATTRS=(SIZE=10) FITPOLICY=ROTATE;
	YAXIS LABEL="Number of Courses";
RUN;

/*The bar chart highlights that IBM and Google are the top providers, suggesting their courses are likely to be aligned with industry-relevant skills and knowledge.

 *The list includes a mix of tech companies (Google, IBM, Google Cloud) and top universities (University of Pennsylvania, Duke, Johns Hopkins, etc.).
 *Investigate why universities have fewer courses and whether there is potential for growth.

 */
PROC SQL OUTOBS=20;
	CREATE TABLE top_20_organization AS SELECT course_organization, 
		MEDIAN(course_rating) AS med_cr FROM proj.coursera_data_cleaned GROUP BY 
		course_organization ORDER BY med_cr DESC;
QUIT;

PROC SGPLOT DATA=top_20_organization;
	HBAR course_organization / RESPONSE=med_cr FILLATTRS=(COLOR=BLUE) 
		CATEGORYORDER=RESPDESC;
	TITLE "Top 20 Organization with Highest Rating Score";
	XAXIS LABEL="Rating Scores(0-5)";
	YAXIS LABEL="Organization";
RUN;


/*Do courses from universities or tech companies have better rating score?*/


PROC SQL;
	SELECT MEDIAN(course_rating) AS course_rating FROM proj.coursera_data_cleaned 
		WHERE course_organization LIKE '%University%';
QUIT;

PROC SQL OUTOBS=10;
	CREATE TABLE uni_vs_tech AS SELECT course_organization, MEDIAN(course_rating) 
		AS med_rr FROM proj.coursera_data_cleaned WHERE course_organization LIKE 
		'%University%' GROUP BY course_organization ORDER BY med_rr DESC;
QUIT;

PROC SQL;
	SELECT MEDIAN(course_rating) AS course_rating FROM proj.coursera_data_cleaned 
		WHERE course_organization  LIKE '%Tech%';
QUIT;

PROC SQL OUTOBS=10;
	CREATE TABLE uni_vs_tech AS SELECT course_organization, MEDIAN(course_rating) 
		AS med_rr FROM proj.coursera_data_cleaned WHERE course_organization  LIKE 
		'%Tech%' GROUP BY course_organization ORDER BY med_rr DESC;
QUIT;

/* Which skills (e.g., Python, Machine Learning, Data Analysis) have the highest rating scores? */
/*Identify Top Skills*/
/* Tokenize the Text Column into Words */
DATA word_tokens;
	SET proj.coursera_data_cleaned;
	LENGTH skills $100;
	course_skills_clean=PRXCHANGE('s/[][(){}''"”“‘’`]+//i', -1, course_skills);

	/* Removes quotes, brackets */
	course_skills_clean=PRXCHANGE('s/^[^a-zA-Z0-9]+|[^a-zA-Z0-9]+$//', -1, 
		course_skills);

	/* Trim edges */
	course_skills_clean=TRANWRD(TRANWRD(TRANWRD(course_skills, "[", ""), "]", ""), 
		"'", "");

	/* Split course skills into words */
	DO i=1 TO COUNTW(course_skills_clean, ',');
		skill=STRIP(SCAN(course_skills_clean, i, ','));
		OUTPUT;
	END;
	DROP i;
RUN;

PROC SQL OUTOBS=10;
	CREATE TABLE skill_freq AS SELECT skill, COUNT(*) AS frequency FROM 
		word_tokens WHERE NOT MISSING(skill) /* Remove empty rows */
		GROUP BY skill ORDER BY frequency DESC;
QUIT;

/* Bar Graph for Top Skills */
PROC SGPLOT DATA=skill_freq;
	HBAR skill / RESPONSE=frequency DATALABEL FILLATTRS=(COLOR=BLUE) 
		CATEGORYORDER=RESPDESC;
	TITLE "Top 10 Skills";
	XAXIS LABEL="Frequency";
	YAXIS LABEL="Skills";
RUN;

PROC SGPLOT DATA=skill_freq;
	BUBBLE X=frequency Y=skill SIZE=frequency / TRANSPARENCY=0.5 DATALABEL=skill;
	XAXIS LABEL="Frequency" GRID;
	YAXIS DISPLAY=(NOLABEL);
	TITLE "Word Cloud Simulation for Skills";
RUN;

PROC SQL OUTOBS=10;
	CREATE TABLE skill_freq AS SELECT skill,MEDIAN(course_rating) AS med_cr, COUNT(*) AS frequency FROM 
		word_tokens WHERE NOT MISSING(skill) /* Remove empty rows */
		GROUP BY skill ORDER BY frequency DESC;
QUIT;


/* Bar Graph for Top Skills */
PROC SGPLOT DATA=skill_freq;
	HBAR skill / RESPONSE=med_cr DATALABEL FILLATTRS=(COLOR=BLUE) 
		CATEGORYORDER=RESPDESC;
	TITLE "Top 10 Skills by Course Rating";
	XAXIS LABEL="Rating Score(0-5)";
	YAXIS LABEL="Skills";
RUN;



/*Do project-based courses have higher retention than OTHER type of courses?
Insight: Measure engagement through interactive content.*/


PROC SGPLOT DATA=proj.coursera_data_cleaned;
	VBOX course_rating / CATEGORY=course_certificate_type TRANSPARENCY=0.2 
		FILLATTRS=(COLOR=BLUE) OUTLIERSATTRS=(COLOR=RED SYMBOL=PLUS);
	XAXIS LABEL="course_certificate_type";
	YAXIS LABEL="Rating Score(0-5)";
	TITLE "Course Rating by Course Certificate Type";
RUN;

/*Do courses with high ratings have higher retention rates?
Insight: Analyze the relationship between satisfaction and completion.*/
PROC SGPLOT DATA=proj.coursera_data_cleaned;
	SCATTER X=course_rating Y=retention_rate / MARKERATTRS=(SYMBOL=circlefilled 
		COLOR=blue SIZE=8);
	REG X=course_rating Y=retention_rate / LINEATTRS=(COLOR=red THICKNESS=2) 
		LEGENDLABEL="Trend Line";
	XAXIS LABEL="Course Rating (Stars)";
	YAXIS LABEL="Retention Rate (%)";
	TITLE "Scatter Plot of Retention Rate vs. Course Rating";
RUN;

/*Is there a correlation between the number of enrolled students and retention rate?
Insight: Explore whether large courses lose engagement.*/
PROC SGPLOT DATA=proj.coursera_data_cleaned;
	SCATTER X=course_students_enrolled Y=retention_rate / 
		MARKERATTRS=(SYMBOL=circlefilled COLOR=blue SIZE=8);
	REG X=course_students_enrolled Y=retention_rate / LINEATTRS=(COLOR=red 
		THICKNESS=2) LEGENDLABEL="Trend Line";
	XAXIS LABEL="Enrollment";
	YAXIS LABEL="Retention Rate (%)";
	TITLE "Scatter Plot of Retention Rate vs. Course Enrollment";
RUN;

/* Bar Graph for Course Difficulty Levels */
PROC SGPLOT DATA=proj.coursera_data_cleaned;
	VBAR course_difficulty / DATALABEL FILLATTRS=(COLOR=BLUE) 
		CATEGORYORDER=RESPDESC;
	TITLE "Distribution of Course Difficulty Levels";
	XAXIS LABEL="Course Difficulty Level" VALUEATTRS=(SIZE=10) FITPOLICY=ROTATE;
	YAXIS LABEL="Number of Courses";
RUN;

/*
Strong Emphasis on Beginners: The large number of beginner courses suggests a focus on broadening access and attracting new learners.


*/
/* Bar Graph for Course Certificate Type */
PROC SGPLOT DATA=proj.coursera_data_cleaned;
	VBAR course_certificate_type / DATALABEL FILLATTRS=(COLOR=BLUE) 
		CATEGORYORDER=RESPDESC;
	TITLE "Distribution of Course Certificate Type";
	XAXIS LABEL="Course Certificate Type" VALUEATTRS=(SIZE=10) FITPOLICY=ROTATE;
	YAXIS LABEL="Number of Courses";
RUN;

/*
Focus on Short-Term Learning: The dominance of Courses and Specializations suggests learners prefer modular, skill-focused content.

*/
/*What are the counts of distribution of course time in the dataset?*/
PROC SGPLOT DATA=proj.coursera_data_cleaned;
	VBAR course_time / DATALABEL FILLATTRS=(COLOR=BLUE) CATEGORYORDER=RESPDESC;
	TITLE "Distribution of Course Course Durations";
	XAXIS LABEL="Period" VALUEATTRS=(SIZE=10) FITPOLICY=ROTATE;
	YAXIS LABEL="Number of Courses";
RUN;

/* Histogram for students_enrolled */
PROC SGPLOT DATA=proj.coursera_data_cleaned;
	HISTOGRAM course_students_enrolled / FILLATTRS=(COLOR=BLUE) TRANSPARENCY=0.3 
		BINWIDTH=100000 SHOWBINS;
	DENSITY course_students_enrolled / TYPE=KERNEL;
	TITLE "Distribution of Students Enrolled";
	XAXIS LABEL="Number of Students Enrolled" MIN=0 MAX=1000000;
	YAXIS LABEL="Number of Courses";
RUN;
/* Box-and-Whisker Plot for Students Enrolled */
PROC SGPLOT DATA=proj.coursera_data_cleaned;
	VBOX course_students_enrolled / OUTLIERSATTRS=(COLOR=RED SYMBOL=PLUS);
	TITLE "Box-and-Whisker Plot of Students Enrolled";
	YAXIS LABEL="Students Enrolled" TYPE=LOG LOGBASE=10 GRID;
	KEYLEGEND / TITLE="Boxplot of Students Enrolled with Highlighted Outliers";
RUN;

/*
Box-whisker:
 * There are numerous outliers above the upper whisker, shown as red points, indicating a few courses with exceptionally high enrollments
 * The whiskers are uneven, with the upper whisker much longer, indicating a positive skew (a few courses have extremely high enrollments compared to the majority).\
 * The Interquartile Range (IQR) is narrow, indicating that most courses have similar enrollment counts.

histogram:
 *The histogram shows a highly right-skewed distribution, with most courses having fewer than 100,000 students
 *The long tail on the right (extending towards 1,000,000) corresponds to the outliers seen in the boxplot.

 */


/*Highlight Best Performers: Feature the top providers’ most popular courses to boost enrollments.*/
PROC SQL OUTOBS=10;
	CREATE TABLE top_10_courses AS SELECT course_title, course_skills, 
		course_rating, SUM(course_students_enrolled) as total_enrollment FROM 
		proj.coursera_data_cleaned GROUP BY course_title, course_skills ORDER BY 
		total_enrollment DESC;
QUIT;

/* Bar Graph for Top Performers */
PROC SGPLOT DATA=top_10_courses;
	HBAR course_title / RESPONSE=total_enrollment FILLATTRS=(COLOR=BLUE) 
		CATEGORYORDER=RESPDESC;
	TITLE "Top 10 Enrolled Courses";
	XAXIS LABEL="Enrollment";
	YAXIS LABEL="Courses";
RUN;

PROC SQL OUTOBS=10;
	CREATE TABLE top_10_courses_rated AS SELECT course_title, course_skills, 
		course_rating FROM proj.coursera_data_cleaned ORDER BY course_rating DESC;
QUIT;

/* Bar Graph for Top Rated Courses */
PROC SGPLOT DATA=top_10_courses_rated;
	HBAR course_title / RESPONSE=course_rating FILLATTRS=(COLOR=BLUE) 
		CATEGORYORDER=RESPDESC;
	TITLE "Top 10 Highly Rated Courses";
	XAXIS LABEL="Rating";
	YAXIS LABEL="Courses";
RUN;



/*Check for Normality*/
PROC UNIVARIATE DATA=proj.coursera_data_cleaned NORMAL;
    VAR course_rating;
    HISTOGRAM / NORMAL;
    QQPLOT / NORMAL;
    PROBPLOT / NORMAL(MU=EST SIGMA=EST);
    TITLE "Normality Check for Course Ratings";
RUN;

/*Since the data is skewed, parametric tests (like t-tests, ANOVA, Pearson correlation) that assume normality may not be appropriate.
Instead, non-parametric models are more appropriate  
*/

PROC SGSCATTER DATA=proj.coursera_data_cleaned;
    MATRIX course_rating course_students_enrolled course_reviews retention_rate;
RUN;

PROC REG DATA=proj.coursera_data_cleaned;
    MODEL course_rating = course_students_enrolled course_reviews retention_rate;
    PLOT residual. * predicted.;
RUN;

PROC SGPLOT DATA=proj.coursera_data_cleaned;
    VBOX course_rating;
RUN;

/*Feature Scaling*/
DATA proj.coursera_scaled_model;
    SET proj.coursera_data_cleaned;
    
    /* Log Transformation to Normalize Skewed Distributions */
    log_students_enrolled = log10(course_students_enrolled + 1); 
    log_course_reviews = log10(course_reviews + 1);

    /* Scale retention rate to 0-1 range */
    scaled_retention_rate = retention_rate / 100; 
    DROP course_title course_url course_skills course_summary course_description course_reviews course_students_enrolled retention_rate;
RUN;

PROC UNIVARIATE DATA=proj.coursera_scaled_model;
    VAR log_students_enrolled log_course_reviews scaled_retention_rate;
    HISTOGRAM log_students_enrolled log_course_reviews scaled_retention_rate;
RUN;

DATA proj.coursera_scaled_model;
	LENGTH organization_category $20; /* Increase character length to 20 */
    SET proj.coursera_scaled_model;
    IF INDEX(LOWCASE(course_organization), "university") > 0 or 
       INDEX(LOWCASE(course_organization), "school") > 0 THEN 
       organization_category = "University";
    ELSE 
       organization_category = "Tech Company";
    DROP course_organization;
RUN;

PROC FREQ DATA=proj.coursera_scaled_model;
    TABLES organization_category;
RUN;

PROC SGSCATTER DATA=proj.coursera_scaled_model;
    MATRIX _NUMERIC_;
RUN;


PROC SQL;
	CREATE TABLE uni_vs_tech AS SELECT organization_category, MEDIAN(course_rating) as med_cr
	FROM proj.coursera_scaled_model GROUP BY organization_category ORDER BY med_cr DESC;
QUIT;

/* Bar Graph for Top Rated Courses */
PROC SGPLOT DATA=uni_vs_tech;
	VBAR organization_category / RESPONSE=med_cr FILLATTRS=(COLOR=BLUE);
	TITLE "Institutions Rating ";
	YAXIS LABEL="Median Rating";
	XAXIS LABEL="Institution";
RUN;



proc surveyselect data=proj.coursera_scaled_model 
    out=train_split samprate=0.7 
    seed=12345 outall;
run;

data proj.train proj.test;
    set train_split;
    if Selected = 1 then output proj.train;
    else output proj.test;
run;




/*One Hot Encoding*/
PROC GLMMOD DATA=proj.train OUTDESIGN=proj.encoded_train;
    CLASS organization_category course_certificate_type course_difficulty course_time;
    MODEL course_rating = organization_category course_certificate_type course_difficulty course_time log_students_enrolled log_course_reviews scaled_retention_rate;
RUN;

PROC GLMMOD DATA=proj.test OUTDESIGN=proj.encoded_test;
    CLASS organization_category course_certificate_type course_difficulty course_time;
    MODEL course_rating = organization_category course_certificate_type course_difficulty course_time log_students_enrolled log_course_reviews scaled_retention_rate;
RUN;

PROC CONTENTS DATA=proj.encoded_train;
RUN;

DATA proj.encoded_test;
    SET proj.encoded_test;
    RENAME Col2 = Tech_Company
           Col3 = University
           Col4 = Course
           Col5 = Guided_Project
           Col6 = Professional_Certificate
           Col7 = Specialization
           Col8 = Advanced
           Col9 = Beginner
           Col10 = Intermediate
           Col11 = Mixed
           Col12 = _1_3_Months
           Col13 = _1_4_Weeks
           Col14 = _3_6_Months
           Col15 = Less_Than_2_Hours
           Col16 = log_students_enrolled
           Col17 = log_course_reviews
           Col18 = scaled_retention_rate;
RUN;


DATA proj.encoded_train;
    SET proj.encoded_train;
    RENAME Col2 = Tech_Company
           Col3 = University
           Col4 = Course
           Col5 = Guided_Project
           Col6 = Professional_Certificate
           Col7 = Specialization
           Col8 = Advanced
           Col9 = Beginner
           Col10 = Intermediate
           Col11 = Mixed
           Col12 = _1_3_Months
           Col13 = _1_4_Weeks
           Col14 = _3_6_Months
           Col15 = Less_Than_2_Hours
           Col16 = log_students_enrolled
           Col17 = log_course_reviews
           Col18 = scaled_retention_rate;
RUN;


PROC CONTENTS DATA==proj.coursera_model_encoded;
RUN;

PROC CORR DATA=proj.coursera_model_encoded OUTP=correlation_matrix NOPROB;
	VAR _NUMERIC_;
RUN;/*nO MULTICOLINEARITY */




/*Regression Tree*/
ods graphics on;
PROC HPSPLIT DATA=proj.encoded_train seed=12345 cvmethod=random(10);
      model course_rating = Beginner Intermediate Advanced 
                          University Tech_Company 
                          _1_3_Months _1_4_Weeks _3_6_Months Less_Than_2_Hours 
                          log_students_enrolled log_course_reviews 
                          scaled_retention_rate;
    grow FTEST;
    prune none;
    output out=proj.training_predictions;
    
RUN;
/*
The tree is now fully grown without pruning, meaning it captures all possible splits from the training data.
Total leaves is 9
Too many leaves can lead to overfitting.
The strongest split occurs at log_course_reviews < 2.358, indicating that courses with fewer reviews tend to have higher ratings
University-offered courses have a high impact on ratings.
Advanced difficulty negatively impacts ratings, suggesting students prefer easier courses.

A low ASE (0.0210) suggests that the model fits the training data well.
However, since this is on training data, we need to evaluate on the test set to check for overfitting.
*/

data proj.regTree_training;
    set proj.training_predictions;
    abs_error = abs(P_course_rating - course_rating);
    squared_error = (P_course_rating - course_rating)**2;
    total_variance = (course_rating - mean(course_rating))**2;
run;

proc means data=proj.regTree_training mean std noprint;
    var abs_error squared_error total_variance;
    output out=regTree_training mean=MAE MSE TotalVar;
run;

data regTree_training;
    set regTree_training;
    RMSE = sqrt(MSE);
    R2 = 1 - (MSE / TotalVar);
run;

proc print data=regTree_training;
run;


PROC HPSPLIT DATA=proj.encoded_test seed=12345 cvmethod=random(10);
      model course_rating = Beginner Intermediate Advanced 
                          University Tech_Company 
                          _1_3_Months _1_4_Weeks _3_6_Months Less_Than_2_Hours 
                          log_students_enrolled log_course_reviews 
                          scaled_retention_rate;
    grow FTEST;
    prune none;
    OUTPUT out=proj.test_predictions;
run;
/*Total leaves is 7
The tree retains all 7 leaves, meaning no pruning was applied.
The model suggests more reviewed courses are rated higher, possibly due to review bias.
Beginner courses have a moderate effect on ratings, implying students may rate them differently than advanced ones.

ASE (0.0209) is similar to the training set (0.0210), meaning no significant overfitting occurred.
RSS (6.0003) is lower than the training set (14.0741), suggesting better generalization.

log_course_reviews is the strongest predictor, reinforcing its dominance in both training and test sets.

Consistent variable importance: The same predictors matter across both training and test sets.
*/


data proj.regTree_test;
    set proj.test_predictions;
    abs_error = abs(P_course_rating - course_rating);
    squared_error = (P_course_rating - course_rating)**2;
    total_variance = (course_rating - mean(course_rating))**2;
run;

proc means data=proj.regTree_test mean std noprint;
    var abs_error squared_error total_variance;
    output out=regTree_test mean=MAE MSE TotalVar;
run;

data regTree_test;
    set regTree_test;
    RMSE = sqrt(MSE);
    R2 = 1 - (MSE / TotalVar);
run;

proc print data=regTree_test;
run;
data model_comparison;
    input Metric $ Type $ Value;
    datalines;
    MAE Training 0.10629
    MAE Test 0.10022
    RMSE Training 0.14483
    RMSE Test 0.14459
    ;
run;

proc sgplot data=model_comparison;
    title "Comparison of Training and Test Sets on Regression Tree";
    vbar Metric / response=Value group=Type groupdisplay=cluster DATALABEL;
    xaxis label="Metric";
    yaxis label="Value";
run;

/*MAE (Mean Absolute Error) is slightly lower in the test set (0.10022) than in the training set (0.10629).
This suggests that the model is not overfitting and performs similarly on both sets.

RMSE (Root Mean Squared Error) is almost identical between training (0.14483) and test (0.14459).This indicates consistent error levels and a well-generalized model.

Since both MAE and RMSE are close between training and test sets, your model generalizes well.
The absence of a large gap between the two sets suggests no significant overfitting or underfitting.
*/





/*Pruned Regression Tree*/
PROC HPSPLIT DATA=proj.encoded_test seed=12345 cvmethod=random(10);
      model course_rating = Beginner Intermediate Advanced 
                          University Tech_Company 
                          _1_3_Months _1_4_Weeks _3_6_Months Less_Than_2_Hours 
                          log_students_enrolled log_course_reviews 
                          scaled_retention_rate;
    grow FTEST;
    PRUNE costcomplexity(leaves=6);/* Pruning */
    OUTPUT out=proj.pruned_test_predictions;
RUN;
/*
adjustment to prune the tree to 6 leaves improved the model by retaining meaningful splits while keeping it simple.
log_course_reviews remains the dominant predictor.
Beginner courses have a moderate effect on ratings, implying students may rate them differently than advanced ones.

More reviews generally indicate higher ratings, which might be due to popular courses attracting more positive engagement.
ASE (0.0338) is lower than the previously over-pruned tree (0.0376), meaning better prediction accuracy.
RSS (9.6986) is reasonable, indicating good balance between model complexity and error reduction.

*/

data proj.Pruned_regTree_test;
    set proj.pruned_test_predictions;
    abs_error = abs(P_course_rating - course_rating);
    squared_error = (P_course_rating - course_rating)**2;
    total_variance = (course_rating - mean(course_rating))**2;
run;

proc means data=proj.Pruned_regTree_test mean std noprint;
    var abs_error squared_error total_variance;
    output out=Pruned_regTree_test mean=MAE MSE TotalVar;
run;

data Pruned_regTree_test;
    set Pruned_regTree_test;
    RMSE = sqrt(MSE);
    R2 = 1 - (MSE / TotalVar);
run;

proc print data=Pruned_regTree_test;
run;




PROC HPSPLIT DATA=proj.encoded_train seed=12345 cvmethod=random(10);
      model course_rating = Beginner Intermediate Advanced 
                          University Tech_Company 
                          _1_3_Months _1_4_Weeks _3_6_Months Less_Than_2_Hours 
                          log_students_enrolled log_course_reviews 
                          scaled_retention_rate;
    grow FTEST;
    PRUNE costcomplexity(leaves=6);/* Pruning */
    OUTPUT out=proj.pruned_training_predictions;
RUN;

/*
log_course_reviews is still the primary split variable
ASE (0.0242) is lower than the earlier pruned test tree (0.0338) → better accuracy.
 6-leaf structure balances complexity and generalization
*/
data proj.Pruned_regTree_train;
    set proj.pruned_training_predictions;
    abs_error = abs(P_course_rating - course_rating);
    squared_error = (P_course_rating - course_rating)**2;
    total_variance = (course_rating - mean(course_rating))**2;
run;

proc means data=proj.Pruned_regTree_train mean std noprint;
    var abs_error squared_error total_variance;
    output out=Pruned_regTree_train mean=MAE MSE TotalVar;
run;

data Pruned_regTree_train;
    set Pruned_regTree_train;
    RMSE = sqrt(MSE);
    R2 = 1 - (MSE / TotalVar);
run;

proc print data=Pruned_regTree_train;
run;





data model_comparison_pruned;
    input Metric $ Type $ Value;
    datalines;
    MAE Training 0.10818
    MAE Test 0.10095
    RMSE Training 0.15114
    RMSE Test 0.14489
    ;
run;

proc sgplot data=model_comparison_pruned;
    title "Comparison of Training & Test Sets on Pruned Regression Tree";
    vbar Metric / response=Value group=Type groupdisplay=cluster DATALABEL;
    xaxis label="Metric";
    yaxis label="Value";
run;
/*MAE and RMSE are close to the unpruned model, showing good generalization.
RMSE is lower than the 6-leaf model, meaning less overfitting.
*/


/* SVM with Linear Kernel */
/* PROC SVMACHINE DATA=proj.coursera_data_cleaned; */
/*     TARGET course_rating; */
/*     INPUT course_time course_reviews course_students_enrolled retention_rate / LEVEL=interval; */
/*     KERNEL LINEAR; */
/* RUN; */
/*  */
/* SVM with RBF */
/* PROC SVMACHINE DATA=proj.coursera_data_cleaned; */
/*     TARGET course_rating; */
/*     INPUT course_time course_reviews course_students_enrolled retention_rate / LEVEL=interval; */
/*     KERNEL rbf; */
/* RUN; */
/*  */
/* SVM Poly */
/* PROC SVMACHINE DATA=proj.coursera_data_cleaned; */
/*     TARGET course_rating; */
/*     INPUT course_time course_reviews course_students_enrolled retention_rate / LEVEL=interval; */
/*     KERNEL poly; */
/* RUN; */
/*  */
/* k-nn */
/* PROC DISCRIM DATA=proj.coursera_data_cleaned METHOD=neighbor K=5; */
/*     CLASS course_rating; */
/* 	VAR course_time course_reviews course_students_enrolled retention_rate; */
/* RUN; */
/*  */
/* NN */
/* PROC NNET DATA=proj.coursera_data_cleaned; */
/*     TARGET course_rating; */
/*     INPUT course_time course_reviews course_students_enrolled retention_rate; */
/*     HIDDEN 5; /* Number of hidden neurons */
/*     TRAIN OUTMODEL=nn_model; */
/* RUN; */

