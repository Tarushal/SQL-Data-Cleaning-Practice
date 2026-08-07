-- =========================================
-- SQL DATA CLEANING PROJECT
-- =========================================

-- Project Workflow
-- 1. REMOVE DUPLICATES
-- 2. STANDARDIZE THE DATA - remove unnecessary variations in data
-- 3. NULL VALUES or BLANK VALUES
-- 4. REMOVE UNWANTED COLUMNS - not always advisable

-- To preserve the original dataset, create a staging table.
-- All cleaning operations will be performed on the staging table, leaving the raw data unchanged.

CREATE TABLE layoffs_staging   -- creates a table with same columns as layoffs table
LIKE layoffs;

SELECT *                       -- checking
FROM layoffs_staging;

-- Insert all records into the staging table
INSERT INTO layoffs_staging    -- we dont use VALUE keyword here bec we are not providing values manually
SELECT *                       -- instead, we are telling SQL to fill values using whatever values the query returns
FROM layoffs;

-- From this point onward, all transformations are performed on the staging table.
-- This preserves the integrity of the original dataset.

-- =========================================
-- STEP 1: REMOVE DUPLICATE RECORDS
-- =========================================

-- Logic: we need to assign a row_number to each row for identification, using Row_number()
-- then, we 'partition by' using MULTIPLE COLUMNS specifically - this creates a unique combination of values at every row, 
-- thereby making it the first time SQL encounters that combination and thus assigns it row num 1
-- in this way, every row (which has a unique combo of values) will be row num 1
-- AND ONLY WHEN some row has the same combination of values as some previous row, thus, making it a duplicate
-- SQL will then assign it row num 2
-- AND THEN we can run a WHERE-filter to fetch only those rows with a row_num = 2 or above; AND DELETE THEM

-- CREATING A CTE FOR DUPLICATE REMOVAL USING ROW_NUMBER()
WITH duplicate_removal AS
(
SELECT *, ROW_NUMBER() OVER 
(PARTITION BY company, location, industry, total_laid_off, percentage_laid_off, `date`, stage, country, funds_raised_millions) AS row_num  -- we use backticks on date col to differentiate it from the keyword date
FROM layoffs_staging
)
DELETE 
FROM duplicate_removal
WHERE row_num > 1;

-- AT THIS POINT WE FOUND OUT that we need to 'partition by' every single column 
-- because the existing 'partiton by' FAILED to detect true duplicates and returned unique rows with only some parameters are common 
-- so we made the change to our code at line 45  

-- NOW we made a CTE and found out the duplicates
-- BUT we CANNOT DELETE them from the CTE as a CTE is NOT UPDATABLE and a delete operation is a kind of update

-- SO we create another table and copy the CTE query into it - right clicked on layoff_staging > copy to clipboard > create statement > paste here

CREATE TABLE `layoffs_staging2` (
  `company` text,
  `location` text,
  `industry` text,
  `total_laid_off` int DEFAULT NULL,
  `percentage_laid_off` text,
  `date` text,
  `stage` text,
  `country` text,
  `funds_raised_millions` int DEFAULT NULL,
  `row_num` INT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


-- fill it with the values from CTE query
INSERT INTO layoffs_staging2
SELECT *, ROW_NUMBER() OVER 
(PARTITION BY company, location, industry, total_laid_off, percentage_laid_off, `date`, stage, country, funds_raised_millions) AS row_num  -- we use backticks on date col to differentiate it from the keyword date
FROM layoffs_staging;

SELECT *                   -- checking & rechecking
FROM layoffs_staging2
WHERE row_num > 1;

-- NOW we can easily delete it since we'd be deleting from a table, not a CTE
DELETE
FROM layoffs_staging2
WHERE row_num > 1;

-- Duplicate records removed successfully.

-- =========================================
-- STEP 2: STANDARDIZE DATA
-- =========================================

-- We need to go over each column, prioritizing the ones most prone to have variations
-- And check for the minute variations and fix it, to standardize them

-- A. We have to trim all the white spaces in front of the COMPANY names

SELECT DISTINCT company, TRIM(company)    -- checking and comparing
FROM layoffs_staging2;

-- Remove leading and trailing whitespace from company names
UPDATE layoffs_staging2
SET company = TRIM(company);


-- B. We fix variations in the INDUSTRY col and make all crypto industries have only 'Crypto' as their value

SELECT DISTINCT(industry)
FROM layoffs_staging2;      -- we find Crypto, CryptoCurrency, Crypto Currency, AND we need to change all of them to 'Crypto'

UPDATE layoffs_staging2     -- update the industry col to 'Crypto', Wherever the industry has the word 'Crypto' in it
SET industry = 'Crypto'
WHERE industry like 'Crypto%';

SELECT DISTINCT(industry)
FROM layoffs_staging2
WHERE industry LIKE 'Crypto%';  -- Confirming that all the variations have been standardized

-- C. Next, we look at the LOCATION col 

SELECT DISTINCT(location)
FROM layoffs_staging2;   -- DID NOT FIND ANY VARIATIONS IN VALUES

-- D. Now, we look at the COUNTRY col

SELECT DISTINCT country
FROM layoffs_staging2
ORDER BY 1;

-- FOUND: 'United States' and 'United States.', so we will fix it

SELECT DISTINCT country, TRIM(TRAILING '.' FROM country)   -- instead of trimming white spaces, this would trim the '.' that's trailing (in the country name), from the country column
FROM layoffs_staging2
ORDER BY 1;

UPDATE layoffs_staging2
SET country = TRIM(TRAILING '.' FROM country)  -- sets country value as the trimmed version of the very same country value
WHERE country LIKE 'United States%';           -- at the place where country looks like united states

-- Checked and Confirmed, earlier DISTINCT country showed 2 USA bec of the '.' at the end of one of them
-- Now that has been removed and both are just USA so distinct country now shows only 1 USA

-- E. Next, we look at the DATE column

-- We need to convert the date col from text to date format, for that we use the STR_TO_DATE() function

SELECT *
FROM layoffs_staging2;

-- the STR_TO_DATE() takes 2 args - date and the format
-- 1st arg: date - tells mySQL to look at the col named date
-- 2nd arg: format - tells mySQL to read the text (say, '5/25/2022') as per the the provided format only (%m/%d/%Y)
-- where, acc to the format, the first element should be read as the month, second as the date and the third as the 4 char Year (Y = 4 char year, y = 2 char year)
-- Then mySQL converts the text date into the real date format looking like - 2022-05-25 (it reads the text and interprets what would be the month, date, year acc to the format we provide)

UPDATE layoffs_staging2        -- updates the column values to date values
SET `date` = STR_TO_DATE(`date`, '%m/%d/%Y'); 

-- BUT the column itself is still labeled as a TEXT column, so we change that too
-- ANALOGY - We've a box named text, now we've replaced its contents from text to date, BUT the box itself is still labeled as text
-- this can create problems later when we use the name of the column 'date' to run datetime operation/comparisons bec mySQL will treat it as a text col

ALTER TABLE layoffs_staging2
MODIFY COLUMN `date` DATE;    -- change date col to the datatype date

-- Checked all columns
-- DATA IS STANDARDIZED!


-- =========================================
-- STEP 3. NULL VALUES and BLANK VALUES
-- =========================================

SELECT * 
FROM layoffs_staging2
WHERE total_laid_off IS NULL;          -- '= NULL' doesn't work
-- AND percentage_laid_off IS NULL;   

-- now there are rows where both total_laid_off and percentage_laid_off are NULLS 
-- those columns are useless to us and IT WOULD BE SAFE TO REMOVE THEM IN STEP 4 - REMOVING COLS/ROWS

-- FOR NOW, We'll look for NULLS & BLANKS in other columns

SELECT *
FROM layoffs_staging2
WHERE industry is NULL   -- for NULL
or industry = '';        -- for BLANK

-- We can see that we have both NULLS and BLANKS in the industry col
-- BUT we might be able to fill these values if we get the same company row where the industry col is actually filled and then update these empty cells with the same values
-- BUT we have to be careful to select the same company with the same location (although an airbnb at diff places will still belong to the same industry, it's still good practice to avoid making any errors)

-- The FIRST STEP at tackling these empty values HERE was to have in our data, just one of the empty types - either nulls or blanks
-- It's actually better to convert blanks into NULLS, so we will do that 

UPDATE layoffs_staging2
SET industry = NULL 
WHERE industry = '';

SELECT *                     -- here we can see that Airbnb has 2 rows, one with null indsutry and one with Travel industry  
FROM layoffs_staging2        -- we can use this other row to know that airbnb belongs to the travel industry  
WHERE company = 'Airbnb';    -- so now we know what we have to fill this empty cell with

-- We'll run a SELF JOIN here (with itself) and 
-- check whether in this table does it have one row that's blank and one that's not blank

SELECT t1.company,t1.location,t1.industry,t2.company,t2.location,t2.industry
FROM layoffs_staging2 AS t1
JOIN layoffs_staging2 AS t2
	ON t1.company = t2.company    -- so that we get the same company
    AND t1.location = t2.location -- so we get the same location
WHERE t1.industry IS NULL
AND t2.industry IS NOT NULL;

-- this shows us: (out of the rows with empty industry values) Which rows have a matching row that are not missing the industry value
-- these non industry-empty rows can be used to fill industry values in the ones that are empty

UPDATE layoffs_staging2 AS t1
JOIN layoffs_staging2 AS t2
	ON t1.company = t2.company
    AND t1.location = t2.location
SET t1.industry = t2.industry
WHERE t1.industry IS NULL
AND t2.industry IS NOT NULL;

-- LOGIC: For Update, we used a SELF-JOIN bec we want the update to know where to pickup values (of industry) from, while filling those NULL industry values 
-- we used t1 as the table with NULL industry values and t2 as the table with filled industry values
-- then we matched the rows with the same company and location
-- ONLY those rows were finally SELECTED WHERE t1's industry col was NULL and t2's industry col was filled
-- LASTLY, we UPDATED t1's industry col (which was NULL; like we assigned t1 to have) to have the same value as t2's industry col
-- so what the update self-join did was - take the value from t2 and fill it into the t1's industry col

-- Operation completed successfully.

-- Remarks:
-- There was one row - Bally's Interactive company which laid off only once and thus had no other row to copy the industry value from, so we had to leave it.
-- Also, fields like laid_off, percentage_laid_off and funds_raised are fields which can be populated but it'll take extra efforts and additional info and sources; so we will leave that as well.

-- NULLS CLEARED !!!

-- =========================================
-- STEP 4. REMOVING UNWANTED COLUMNS
-- =========================================

-- Earlier we looked at rows where both laid_off and percentage_laid_off were NULLS (they can be populated with the help of additional info n sources; but we are not gonna do that here)
-- These rows ARE NOT OF MUCH USE to us; so we will have to probably remove them from our dataset

DELETE 
FROM layoffs_staging2
WHERE total_laid_off IS NULL
AND percentage_laid_off IS NULL;

SELECT *                     -- checked and confirmed
FROM layoffs_staging2;

-- NOW we just need to remove the extra col that we created - row_num, since we don't need it anymore

ALTER TABLE layoffs_staging2
DROP COLUMN row_num;

-- AND THAT'S IT

-- DATA CLEANING PROCESS IS COMPLETED.