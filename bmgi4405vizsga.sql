--Balog Mate

CREATE OR ALTER PROCEDURE szamlazas
@vnev NVARCHAR(20),
@datum SMALLDATETIME,
@szosszeg DECIMAL OUTPUT
AS
BEGIN
SET NOCOUNT ON
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE
BEGIN TRAN
	BEGIN TRY
	SET @szosszeg=0
	IF @vnev NOT IN (SELECT NEV FROM Vevok)
		BEGIN
		RAISERROR('NINCS ILYEN VEVO!', 16, 1)
        RETURN -1
		END
	IF @datum>GETDATE()
		BEGIN
		RAISERROR('HIBAS IDOPONT!', 16, 1)
        RETURN -2
		END
	DECLARE @vevoID INT = (SELECT VEVOKOD FROM Vevok WHERE NEV=@vnev)
	IF @vevoID NOT IN (SELECT VEVOKOD FROM Rendelesek)
		BEGIN
		RAISERROR('A VEVONEK NINCS RENDELESE!', 16, 1)
        RETURN -3
		END

	DECLARE @rendelesID INT = (SELECT RENDELESSZAM FROM Rendelesek WHERE VEVOKOD=@vevoID)
	INSERT INTO SzamlaFejek VALUES (@datum,@vevoID,@rendelesID)
	
	DECLARE @ARU INT 
	DECLARE RENDELESCursor CURSOR FOR
    SELECT AruKod FROM Tartalmaz WHERE RendelesSzam = @rendelesID
    OPEN RENDELESCursor
    FETCH NEXT FROM RENDELESCursor INTO @ARU
    
	WHILE @@FETCH_STATUS = 0
		BEGIN
		DECLARE @mennytart DECIMAL = (SELECT Mennyiseg FROM Tartalmaz WHERE RendelesSzam=@rendelesID AND AruKod=@ARU) 
		DECLARE @mennyrakt DECIMAL = (SELECT MENNYRAKT FROM Aruk WHERE ARUKOD=@ARU) 
		DECLARE @darabsz DECIMAL = CASE
								WHEN @mennytart <= @mennyrakt then @mennytart
								WHEN @mennytart >  @mennyrakt then @mennyrakt
								ELSE 0
								END
		DECLARE @ELADAR INT = (SELECT AR FROM Tartalmaz WHERE @ARU=AruKod AND @rendelesID=RendelesSzam)
		
		IF @darabsz != 0	
			BEGIN
			SET @szosszeg = @szosszeg + @ELADAR * @darabsz
			INSERT INTO SzamlaSorok VALUES ((SELECT SzamlaSzam FROM SzamlaFejek WHERE RendelesSzam=@rendelesID),
			@ARU,@darabsz,@ELADAR,@ELADAR*@darabsz)
			DELETE FROM Tartalmaz WHERE @ARU=AruKod AND @rendelesID=RendelesSzam
			UPDATE Aruk SET MENNYRAKT=MENNYRAKT-@darabsz
			END
		
		FETCH NEXT FROM RENDELESCursor INTO @ARU
        END
    CLOSE RENDELESCursor
    DEALLOCATE RENDELESCursor

	COMMIT
	END TRY
	BEGIN CATCH
         SELECT ERROR_MESSAGE() AS ErrorMessage,
         ERROR_NUMBER() AS ErrorNumber,
         ERROR_SEVERITY() AS ErrorSeverity,
         ERROR_STATE() AS ErrorState,
		 ERROR_LINE() AS l 
         ROLLBACK
    END CATCH
	RETURN @szosszeg
END


DECLARE @OSSZEG DECIMAL
EXEC szamlazas 'Kiss János','2021-12-13 18:00:00.000',@OSSZEG
PRINT @OSSZEG

ALTER TABLE TARTALMAZ
ADD AR INT
UPDATE Tartalmaz SET AR=10
select * from Vevok
SELECT * FROM Tartalmaz