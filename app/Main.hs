{-# LANGUAGE OverloadedStrings #-}

import qualified Data.ByteString.Lazy as BL
import qualified Data.Vector as V
import qualified Data.ByteString.Char8 as B
import Data.Csv
import Data.Csv (Header)
import qualified Data.Text as T
import qualified Data.Text.IO as TIO
import qualified Data.Map as M
import Data.Maybe (mapMaybe, fromMaybe)
import Data.Char (isDigit)
import System.Environment (getArgs)
import System.FilePath (takeFileName, (<.>))
import Text.Read (readMaybe)
import System.Directory (getCurrentDirectory)
import System.IO (writeFile)

type Row = M.Map T.Text T.Text

main :: IO ()
main = do
    args <- getArgs
    case args of
        [path] -> runBasic path
        [path, "--summary", col] -> runSummary path (T.pack col)
        [path, "--filter", cond] ->
            let (k, v) = break (== '=') cond
            in if null v then putStrLn "Invalid filter format. Use Column=Value"
               else runFilter path (T.pack k) (T.pack $ drop 1 v)
        [path, "--sql-schema"] -> runSQLSchema path "my_table"
        [path, "--sql-schema", table] -> runSQLSchema path table
        [path, "--print"] -> runPrint path
        _ -> putStrLn usage

usage :: String
usage = unlines
  [ "Usage:"
  , "  Tabulyst <csv-path>"
  , "  Tabulyst <csv-path> --summary <Column>"
  , "  Tabulyst <csv-path> --filter <Column=Value>"
  , "  Tabulyst <csv-path> --sql-schema [TableName]"
  , "  Tabulyst <csv-path> --print"
  ]

-- Load and decode CSV
loadCSV :: FilePath -> IO (Either String (Header, V.Vector Row))
loadCSV path = do
    csv <- BL.readFile path
    return $ decodeByName csv

-- Print column names
summarizeCSV :: V.Vector Row -> IO ()
summarizeCSV rows = do
    putStrLn $ "Loaded " ++ show (V.length rows) ++ " rows."
    let columns = if V.null rows then [] else M.keys (V.head rows)
    putStrLn "Columns:"
    mapM_ TIO.putStrLn columns

-- Basic view + SQL schema
runBasic :: FilePath -> IO ()
runBasic path = do
    result <- loadCSV path
    case result of
        Left err -> putStrLn $ "CSV Error: " ++ err
        Right (_, rows) -> do
            summarizeCSV rows
            generateAndSaveSQL "my_table" rows

runSummary :: FilePath -> T.Text -> IO ()
runSummary path col = do
    result <- loadCSV path
    case result of
        Left err -> putStrLn $ "CSV Error: " ++ err
        Right (_, rows) -> do
            let values = mapMaybe (M.lookup col) (V.toList rows)
            putStrLn $ "Summary for column: " ++ T.unpack col
            mapM_ TIO.putStrLn values

runFilter :: FilePath -> T.Text -> T.Text -> IO ()
runFilter path key val = do
    result <- loadCSV path
    case result of
        Left err -> putStrLn $ "CSV Error: " ++ err
        Right (header, rows) -> do
            let filtered = V.filter (\r -> M.lookup key r == Just val) rows
            putStrLn $ "Filtered rows where " ++ T.unpack key ++ " = " ++ T.unpack val
            mapM_ printRow (V.toList filtered)
            let outName = "filtered_" ++ takeFileName path
            let encoded = encodeByName header (V.toList filtered)
            BL.writeFile outName encoded
            putStrLn $ "Filtered CSV saved to: " ++ outName

runSQLSchema :: FilePath -> String -> IO ()
runSQLSchema path table = do
    result <- loadCSV path
    case result of
        Left err -> putStrLn $ "CSV Error: " ++ err
        Right (_, rows) -> generateAndSaveSQL table rows

runPrint :: FilePath -> IO ()
runPrint path = do
    result <- loadCSV path
    case result of
        Left err -> putStrLn $ "CSV Error: " ++ err
        Right (_, rows) -> mapM_ printRow (V.toList rows)

printRow :: Row -> IO ()
printRow r = TIO.putStrLn $ T.intercalate " | " $ M.elems r

-- Infer and save SQL schema
generateAndSaveSQL :: String -> V.Vector Row -> IO ()
generateAndSaveSQL tableName rows = do
    let sql = inferSQLSchema tableName rows
    putStrLn "\nInferred SQL Schema:"
    putStrLn sql
    let outFile = tableName <.> "sql"
    writeFile outFile sql
    putStrLn $ "Schema saved to " ++ outFile

-- Infer SQL types with PRIMARY KEY and NOT NULL
inferSQLSchema :: String -> V.Vector Row -> String
inferSQLSchema tableName rows
    | V.null rows = "-- No data to infer schema."
    | otherwise =
        let sampleRows = V.toList $ V.take 100 rows
            headers = M.keys (V.head rows)
            columnSamples = [(col, mapMaybe (M.lookup col) sampleRows) | col <- headers]
            schemaLines = [columnLine col vals | (col, vals) <- columnSamples]
        in "CREATE TABLE " ++ tableName ++ " (\n" ++ unlines (addCommas schemaLines) ++ ");"

columnLine :: T.Text -> [T.Text] -> String
columnLine name values =
    let cname = T.unpack name
        ctype = guessSQLType values
        notnull = if all (not . T.null . T.strip) values then " NOT NULL" else ""
        pk = if T.toLower name == "id" then " PRIMARY KEY" else ""
    in "  " ++ cname ++ " " ++ ctype ++ notnull ++ pk

guessSQLType :: [T.Text] -> String
guessSQLType values
    | all isInteger cleaned = "INTEGER"
    | all isDoubleLike cleaned = "REAL"
    | otherwise = "TEXT"
  where
    cleaned = map T.strip values
    isInteger t = T.all isDigit t && not (T.null t)
    isDoubleLike t = case readMaybe (T.unpack t) :: Maybe Double of
        Just _ -> True
        _ -> False

addCommas :: [String] -> [String]
addCommas [] = []
addCommas [x] = [x]
addCommas (x:xs) = (x ++ ",") : addCommas xs
