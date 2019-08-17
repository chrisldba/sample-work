/*
This was the 1st project I collaborated with a colleague remotely over 3 time zones away.  I was brought onboard to his idea of using SQL Server 
to create an even number of high-selling and low-selling dealers (400+ total) for each sales rep (~16) nation-wide.  The goal in the end was to 
use the geography attribute to help calculate distance for each.
After 4 - 6 months the project was a complete failure.  Because of that, it's still one of my favorite projects.
*/

use dkor
go

-- Verifying the pre-existing info that was needed to work with.

select reference_no, store_nm, a.address_line1_ds, city_nm, province_id, postal_code_cl 
	from store s
	inner join a.address_id a on s.address_id = a.id
	order by province_id, city_nm

select id, reference_no, first_nm, last_nm, territory_nm, last_update_dt 
	from representative
	order by last_update_dt

-- Step 1: Confirming temp tables and cursor operate as expected -----------------------------------------------

create table #cursorcopy								-- 1st temp table.
(FirstName varchar(20), LastName varchar(20), Phone int)
create table #cursorpaste								-- Duplicate 2nd temp table of the 1st.
(FirstName varchar(20), LastName varchar(20), Phone int)
insert into #cursorcopy (FirstName, LastName, Phone)	-- Dummy data.
values	('Vlad', 'Savic', 123456),
		('Chris', 'Leopold', 654321),
		('Sam', 'Sully', 987654),
		('Nic', 'Rioux', 456789),
		('Dave', 'Wright', 147258)
select * from #cursorcopy								-- Confirming the 1st temp table worked

declare @fn as varchar(20);
declare @ln as varchar(20);
declare @phone as int
declare @transfer as cursor;
 
set @transfer = cursor for
	select FirstName, LastName, Phone
	from #cursorcopy
open @transfer

fetch next from @transfer into @fn, @ln, @phone
while @@fetch_status = 0
begin
	-- insert into #cursorpaste from @fn, @ln, @phone		-> Produces an error.
	-- select @fn, @ln, @phone								-> Worked, though copies everything 5 times.
	-- from #cursorcopy										-> Seems optional, had no effect.
	-- insert into #cursorpaste values (@fn, @ln, @phone)	-> Worked, though copies everything 10 times.
	insert into #cursorpaste values (@fn, @ln, @phone) --	-> Working now
	-- print (@fn, @ln, @phone)								-> Produced error, but turns out not needed
	-- print convert (@fn, @ln, @phone)						-> Produced error, but turns out not needed.
	fetch next from @transfer into @fn, @ln, @phone
end

select * from #cursorcopy								-- Comparing the 1st temp table to 2nd.
select * from #cursorpaste								-- Confirming the 2nd temp table worked and comparing to the 1st.

close @transfer
deallocate @transfer
drop table #cursorcopy
drop table #cursorpaste

-- Step 2: Matching rep and store dummy data -----------------------------------------------------------------------------

-- Checking if temp tables already exist, and if they do, drop them (they'll be re-created later)
if object_id ('tempdb..#stores') is not null
    drop table #stores
if object_id ('tempdb..#reps') is not null
	drop table #reps
set nocount on

create table #stores								
	(id int, StoreName varchar(20), 
	Lat varchar(20), 
	Long varchar(20), 
	RepID int null, 
	DistanceToRep varchar(20))

create table #reps								
	(id int identity (1, 1) primary key, 
	FirstName varchar(20), 
	Lat varchar(20), 
	Long varchar(20))

insert into #stores (id, StoreName, Lat, Long)					-- Dummy data.
values (1, 'Walker Group', '49.3275791', '-123.1555861'),		-- Something West
	   (2, 'Lexus of Saint John', '45.2834123', '-66.0525388'), -- Something East
	   (3, 'OpenRoad Lexus', '49.2766440', '-122.8351134')		-- Something West

insert into #reps (FirstName, Lat, Long)						-- Dummy data.
values ('Vlad', '43.8112519', '-79.3628982'),
	   ('Chris', '49.2483853', '-123.10881')

select * from #stores											-- Ensuring temp tables operating.
select * from #reps

-- Altering the table to create a spatial indiex using a geography point based on lattitude and longitude.
alter table #reps add [p] as geography::point(Lat, Long, 4326) persisted;  --> [p] is for Point
create spatial index [spatialIndex] on #reps ([p])

declare @id as int;
declare @StoreName as varchar(20);
declare @Lat as varchar(20);
declare @Long as varchar(20);
 
declare storeCursor cursor for 
	select id, StoreName, Lat, Long 
	from #stores
open storeCursor

fetch next from storeCursor into @id, @StoreName, @Lat, @Long
while @@fetch_status = 0
begin
	print 'Finding the nearest sales rep for store id '+str(@ID) 
	declare @matchedRepresentativeId int
	declare @distanceToRep varchar(20)
	declare @g geography = geography::parse('Point (' + cast(@Long as varchar(20)) + ' ' + cast(@Lat as varchar(20)) + ')')
	select top (1) @matchedRepresentativeId = id, @distanceToRep=rtrim(ltrim(str(round(p.STDistance(@g)/1000,2))))+' Km' 
		from #reps 
		order by p.STDistance(@g)
	print 'Updated store with matched sales rep ID: ' + str(@matchedRepresentativeId)
	update s set s.RepID = @matchedRepresentativeId, s.DistanceToRep = @distanceToRep 
		from #stores s 
		where s.ID = @ID
fetch next from storeCursor into @ID, @StoreName, @Lat, @Long
end

close storeCursor
deallocate storeCursor

SELECT * FROM #stores												-- Ensuring temp table displaying expected results

-- Step 3: Selecting the top 5 stores for each rep ---------------------------------------------------------------------------------------

-- Checking if temp tables already exist, and if they do, drop them (they'll be re-created later)
if object_id ('tempdb..#stores') is not null
    drop table #stores
if object_id ('tempdb..#reps') is not null
    drop table #reps
set nocount on

create table #stores                                
	(id int, StoreName varchar(20), 
	Lat varchar(20), 
	Long varchar(20), 
	RepID int null, 
	DistanceToRep varchar(20))

create table #reps                                
	(id int identity (1, 1) primary key, 
	FirstName varchar(20), 
	Lat varchar(20), 
	Long varchar(20))

insert into #stores (id, StoreName, Lat, Long)				-- Dummy data. 
values (1, 'Walker Group', '49.3275791', '-123.1555861'),         
       (2, 'Lexus of Saint John', '45.2834123', '-66.0525388'), 
       (3, 'OpenRoad Lexus', '49.2766440', '-122.8351134'), 
       (4, 'Campus Honda', '48.444721', '-123.373993'),
       (5, 'MCL Motors', '49.270351', '-123.144737'),
       (6, 'Rally Subaru', '53.467098', '-113.476692'),
       (7, 'Lexus of Calgary', '51.072269', '-114.006439'),
       (8, 'Saskatoon Hyundai', '52.156441', '-106.671127'),
       (9, 'Autohaus VW', '49.862370', '-97.147957'),
       (10, 'Toronto Kia', '43.686821', '-79.309380'),
       (11, 'Thunder Bay Auto', '48.3842211', '-89.2577078'),
       (12, 'Ottawa Car Sales', '45.4059621', '-75.7230078'),
       (13, 'Montreal Char Vendes', '45.4870681', '-73.5855928'),
       (14, 'Mirimachi Motors', '47.0315521', '-65.5062488'),
       (15, 'Sydney Sales', '46.1342151', '-60.1907248')
    
insert into #reps (FirstName, Lat, Long)					-- Dummy data.  
values ('Vladica', '43.8112519', '-79.3628982'),
       ('Chris', '49.2483853', '-123.10881'),
       ('April', '53.9165931','-122.7666168'),
       ('Betty', '53.5388751','-113.5080048'),
       ('Dan', '52.2680391','-113.8228838'),
       ('Erika', '51.0476521','-114.0802668'),
       ('Frank', '52.1271412','-106.6733288'),
       ('Hariott', '50.4551252','-104.5952908'),
       ('Jack', '53.8258782','-101.2553798'),
       ('Kelly', '49.9467591','-97.1534988'),
       ('Mario', '45.4884181','-73.4640748'),
       ('Oliver', '45.9238241','-65.8056738'),
       ('Pat', '46.2549052','-63.7034858'),
       ('Rachel', '45.0868071','-63.4132808'),
       ('Xander', '47.4705011','-55.8357248')

-- Alter the table to create a spatial index with a geography point based on lattitude and longitude.
alter table #reps add [p] as geography::point(Lat, Long, 4326) persisted;  --> [p] is for Point
create spatial index [spatialIndex] on #reps ([p])

declare @id as int;
declare @StoreName as varchar(20);
declare @Lat as varchar(20);
declare @Long as varchar(20);
 
declare storeCursor cursor for 
	select id, StoreName, Lat, Long from #stores 
open storeCursor

fetch next from storeCursor into @id, @StoreName, @Lat, @Long
while @@fetch_status = 0
begin
	declare @matchedRepresentativeId int
	declare @distanceToRep varchar(20)
	declare @g geography = geography::parse('Point (' + cast(@Long as varchar(20)) + ' ' + cast(@Lat as varchar(20)) + ')')
	SELECT TOP (5) *, rtrim(ltrim(str(round(p.STDistance(@g)/1000,2)))) as 'Distance in KM' 
		from #reps r order by p.STDistance(@g)
	-- Nothing will show yet as 5 results can't be put into 1 variable, but will be completed on the next step.
fetch next from storeCursor into @id, @StoreName, @Lat, @Long
end

close storeCursor
deallocate storeCursor

-- Step 4: Ensuring there's a 200 km maximum distance between reps and dealers ------------------------------------------

-- Checking if temp tables already exist, and if they do, drop them (they'll be re-created later)
if object_id ('tempdb..#stores') is not null
    drop table #stores
if object_id ('tempdb..#reps') is not null
    drop table #reps
if object_id ('tempdb..#top5') is not null
	drop table #top5
set nocount on

create table #stores                                
	(id int, StoreName varchar(20), 
	Lat varchar(20), 
	Long varchar(20), 
	RepID int null, 
	DistanceToRep varchar(20))

create table #reps                                
	(id int identity (1, 1) primary key, 
	FirstName varchar(20), 
	Lat varchar(20), 
	Long varchar(20))

insert into #stores (id, StoreName, Lat, Long)				-- Dummy data.
values (1, 'Walker Group', '49.3275791', '-123.1555861'),         
       (2, 'Lexus of Saint John', '45.2834123', '-66.0525388'), 
       (3, 'OpenRoad Lexus', '49.2766440', '-122.8351134'),         
       (4, 'Campus Honda', '48.444721', '-123.373993'),
       (5, 'MCL Motors', '49.270351', '-123.144737'),
       (6, 'Rally Subaru', '53.467098', '-113.476692'),
       (7, 'Lexus of Calgary', '51.072269', '-114.006439'),
       (8, 'Saskatoon Hyundai', '52.156441', '-106.671127'),
       (9, 'Autohaus VW', '49.862370', '-97.147957'),
       (10, 'Toronto Kia', '43.686821', '-79.309380'),
       (11, 'Thunder Bay Auto', '48.3842211', '-89.2577078'),
       (12, 'Ottawa Car Sales', '45.4059621', '-75.7230078'),
       (13, 'Montreal Char Vendes', '45.4870681', '-73.5855928'),
       (14, 'Mirimachi Motors', '47.0315521', '-65.5062488'),
       (15, 'Sydney Sales', '46.1342151', '-60.1907248')
    
insert into #reps (FirstName, Lat, Long)					-- Dummy data.
values ('Vlad', '43.8112519', '-79.3628982'),
       ('Chris', '49.2483853', '-123.10881'),
       ('April', '53.9165931','-122.7666168'),
       ('Betty', '53.5388751','-113.5080048'),
       ('Dan', '52.2680391','-113.8228838'),
       ('Erika', '51.0476521','-114.0802668'),
       ('Frank', '52.1271412','-106.6733288'),
       ('Hariott', '50.4551252','-104.5952908'),
       ('Jack', '53.8258782','-101.2553798'),
       ('Kelly', '49.9467591','-97.1534988'),
       ('Mario', '45.4884181','-73.4640748'),
       ('Oliver', '45.9238241','-65.8056738'),
       ('Pat', '46.2549052','-63.7034858'),
       ('Rachel', '45.0868071','-63.4132808'),
       ('Xander', '47.4705011','-55.8357248')

-- Alter the table to create a spatial index with a geography point based on lattitude and longitude.
alter table #reps add [p] as geography::point(Lat, Long, 4326) persisted;  --> [p] is for Point
create spatial index [spatialIndex] on #reps ([p])

declare @id as int;
declare @StoreName as varchar(20);
declare @Lat as varchar(20);
declare @Long as varchar(20);
 
declare storeCursor cursor for 
	select id, StoreName, Lat, Long from #stores
open storeCursor

fetch next from storeCursor into @id, @StoreName, @Lat, @Long
while @@fetch_status = 0
begin
	declare @matchedRepresentativeId varchar
	declare @distanceToRep varchar(20)
	declare @g geography = geography::parse('Point (' + cast (@Long as varchar(20)) + ' ' + cast (@Lat as varchar(20)) + ')')
	select top (5) *, rtrim(ltrim(str(round(p.STDistance(@g)/1000,2)))) as 'Distance in KM' 
		from #reps r order by p.STDistance(@g)
	declare top5Cursor cursor 
		for select FirstName, p.STDistance(@g) from #reps
	open top5Cursor
	fetch next from top5Cursor into @matchedRepresentativeId, @distanceToRep			
	while @@fetch_status = 0
		begin
			select top (5) *, rtrim(ltrim(str(round(p.STDistance(@g)/1000,2)))) as 'Distance in KM' into #top5 
			from  #reps r 
			where p.STDistance(@g) < 200
			order by p.STDistance(@g)
		fetch next from top5Cursor into @matchedRepresentativeId, @distanceToRep
		end
	close top5Cursor
	deallocate top5Cursor 
	fetch next from storeCursor into @id, @StoreName, @Lat, @Long
end

close storeCursor
deallocate storeCursor

-- Confirming reps and stores are matched up.
SELECT * FROM #stores
select * from #top5