/*
Project: Covid-19 Data Exploration (SQL)
*/

SELECT *
FROM PortfolioProject..CovidDeaths
ORDER BY location, date;

SELECT location, date, population, total_cases, new_cases, total_deaths, new_deaths
FROM PortfolioProject..CovidDeaths
ORDER BY location, date;

-- Check missing Values
SELECT 
SUM(CASE WHEN location is null THEN 1 ELSE 0 END) as missing_location,
SUM(CASE WHEN date is null THEN 1 ELSE 0 END) as missing_date,
SUM(CASE WHEN population is null THEN 1 ELSE 0 END) as missing_population
FROM PortfolioProject..CovidDeaths;

-- Percentage of population infected by country
SELECT location, population, MAX(total_cases) AS total_cases, (MAX(total_cases)/population)*100 as total_infected
FROM PortfolioProject..CovidDeaths
WHERE continent is not null
GROUP BY location, population
ORDER BY total_infected DESC;

--Infection rate in the UK based on each month
SELECT location, format(date, 'yyyy-MM') as month, population, MAX(total_cases) AS total_cases, (MAX(total_cases)/population)*100 as total_infected
FROM PortfolioProject..CovidDeaths
WHERE continent is not null
and location= 'United Kingdom'
GROUP BY location, format(date, 'yyyy-MM'), population
ORDER BY month;

-- Death percentage by continent
SELECT continent,
SUM(CAST(new_cases as float)) as total_cases, SUM(CAST(new_deaths as float)) as total_deaths,
SUM(CAST(new_deaths as float))/SUM(CAST(new_cases as float))*100 as death_percentage
FROM PortfolioProject..CovidDeaths
WHERE continent is not null
GROUP BY continent
ORDER BY death_percentage;

-- Global daily covid death rate
SELECT date, SUM(CAST(new_cases as float)) as total_cases,
SUM(CAST(new_deaths as float)) as total_deaths,
(SUM(CAST(new_deaths as float))/ SUM(CAST(new_cases as float)))*100 AS death_rate
FROM PortfolioProject..CovidDeaths
WHERE continent is not null
GROUP BY date
ORDER BY date;

-- Rolling global deaths
SELECT date, SUM(CAST(new_cases as float)) as total_cases,
SUM(CAST(new_deaths as float)) as total_deaths,
SUM(SUM(CAST(new_deaths as float))) OVER (ORDER BY date ROWS UNBOUNDED PRECEDING) AS rolling_total_death
FROM PortfolioProject..CovidDeaths
WHERE continent is not null
GROUP BY date
ORDER BY date;

-- Countries with the highest infection rate compared to population
SELECT location,population, sum(new_cases) as total_cases, 
(sum(new_cases)/population)*100 as infection_rate
FROM PortfolioProject..CovidDeaths
WHERE continent is not null
GROUP BY location, population
ORDER BY infection_rate DESC;

--CTE population vs vaccination percentage
WITH popVSvac AS (
SELECT dea.location, dea.date, dea.population, vac.new_vaccinations,
SUM(CAST(vac.new_vaccinations as float)) OVER (PARTITION BY dea.location ORDER BY dea.date) as total_vaccinated
FROM PortfolioProject..CovidDeaths as dea
JOIN PortfolioProject..CovidVaccinations as vac
on dea.location=vac.location and dea.date=vac.date
WHERE dea.continent is not null)

SELECT *, (total_vaccinated/population)*100 as vaccination_percentage
FROM popVSvac
ORDER BY location, date;

-- Using temp table to perform calculation
DROP TABLE if exists #temp_table
CREATE TABLE #temp_table(
location nvarchar(255),
date DATE,
population FLOAT,
new_cases FLOAT,
new_deaths FLOAT,
new_vaccinations FLOAT
);

INSERT INTO #temp_table
SELECT dea.location, dea.date, dea.population, dea.new_cases, dea.new_deaths, vac.new_vaccinations
FROM PortfolioProject..CovidDeaths AS dea
JOIN PortfolioProject..CovidVaccinations AS vac
ON dea.location = vac.location
AND dea.date = vac.date
WHERE dea.continent is not null;

-- Percentage of total population died from covid-19
SELECT location, population, SUM(new_cases) as total_infected, SUM(new_deaths) as total_death,
(SUM(new_deaths)/SUM(new_cases))*100 as death_rate,
(SUM(new_deaths)/population)*100 as death_percentage_of_population
FROM #temp_table
GROUP BY location, population
ORDER BY death_percentage_of_population DESC;

-- Create view
CREATE VIEW death_and_vaccinations AS
SELECT dea.location, dea.population, SUM(CAST(dea.new_deaths as FLOAT)) as total_deaths,
SUM(CAST(vac.new_vaccinations as FLOAT)) as total_vaccinated
FROM PortfolioProject..CovidDeaths as dea
JOIN PortfolioProject..CovidVaccinations as vac
ON dea.location=vac.location
AND dea.date= vac.date
WHERE dea.continent is not null
GROUP BY dea.location, dea.population;

-- Total death per milliom
SELECT *, (total_deaths/population)*1000000 as death_per_million
FROM death_and_vaccinations
ORDER BY death_per_million DESC;
