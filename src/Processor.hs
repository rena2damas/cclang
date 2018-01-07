module Processor where

import Stack
import System.IO
import Data.List
import Data.Bits

-- Types
type Name = String
type Arity = Int
type Token = String
type Macro = (Name, Arity, [Token])

type Value = Integer
type Variable = (Name, Value)

type State = ([Variable], Stack Integer, String)
type Program = ([Macro], State, [Token])

-- Lists all supported operators
supportedOperators :: [String]
supportedOperators = words "+ - * / % < <= > >= == & | !"

-- Applies token to the current state resulting in a different state
evalToken :: [Macro] -> State -> Token -> State
evalToken macros (vars, Stack stack, out) token
  | token == ","                      = (vars, snd . evalSinglePop $ Stack stack, out ++ (show . fst . evalSinglePop $ Stack stack) ++ [' '])
  | token == "."                      = (vars, snd . evalSinglePop $ Stack stack, out ++ (show . fst . evalSinglePop $ Stack stack) ++ ['\n'])
  | elem token supportedOperators     = (vars, evalExpression token $ Stack stack, out)
  | token !! 0 == '@'                 = (setVar vars (['@'] ++ token) $ fst . evalSinglePop $ Stack stack, snd . evalSinglePop $ Stack stack, out)
  | otherwise                         = (vars, push (read token :: Integer) $ Stack stack, out)

evalExpression :: String -> Stack Integer -> Stack Integer
evalExpression token (Stack stack) = case token of
  "+" -> evalDoubleArg (+) $ Stack stack
  "-" -> evalDoubleArg (-) $ Stack stack
  "*" -> evalDoubleArg (*) $ Stack stack
  "/" -> evalDoubleArg (div) $ Stack stack
  "%" -> evalDoubleArg (mod) $ Stack stack
  "<" -> evalDoubleArg (<) $ Stack stack
  "<=" -> evalDoubleArg (<=) $ Stack stack
  ">" -> evalDoubleArg (>) $ Stack stack
  ">=" -> evalDoubleArg (>=) $ Stack stack
  "==" -> evalDoubleArg (==) $ Stack stack
  "&" -> evalDoubleArg (.&.) $ Stack stack
  "|" -> evalDoubleArg (.|.) $ Stack stack
  "!" -> evalDoubleArg (!) $ Stack stack
    where
      evalSingleArg op (Stack stack) = push (op (fst . evalSinglePop $ Stack stack)) (Stack $ drop 1 stack)
      evalDoubleArg op (Stack stack) = push (op (fst . evalPop 2 $ Stack stack) (fst . evalSinglePop $ Stack stack)) (Stack $ drop 2 stack)
      (!) a = if a == 0 then 1 else 0

evalPop :: Int -> Stack Integer -> (Integer, Stack Integer)
evalPop n (Stack stack) = case pop $ Stack $ drop (n-1) stack of
  (Nothing, _)           -> error "poping empty stack"
  (Just x, Stack stack') -> (x, Stack stack')

evalSinglePop :: Stack Integer -> (Integer, Stack Integer)
evalSinglePop (Stack stack) = evalPop 1 $ Stack stack

-- Computes the final state of a program from a starting point state
eval :: Program -> State
eval (_, state, []) = state
eval (macros, state, (token:tokens)) = eval (macros, evalToken macros state token, tokens)

-- Builds up program based on file data and returns result from eval
processData :: String -> IO State
processData rawFileData = return $ eval (macros, initialState, tokens)
  where
    tokens = words $ unlines $ drop (numMacros + 1) fileData
    initialState = ([], Stack [], "")
    macros = loadMacros numMacros (tail fileData)
    numMacros = read $ head fileData
    loadMacros n (l:ls) = if n == 0 then [] else readMacro l : loadMacros (n-1) ls
    fileData = removeComments $ lines $ rawFileData
    removeComments fd = filter (\line -> head line /= '#') fd

-- Reads data from text file and outputs result from processData
run :: FilePath -> IO ()
run filepath = do
  contents <- readFile filepath
  (_, _, output) <- processData $ contents
  putStrLn output

-- Reading a macro from string
readMacro :: String -> Macro
readMacro line = readMacro' $ words line
  where
    readMacro' ls = ((['$'] ++ head ls), (read $ head $ tail ls), (drop 2 ls))

-- Get macro token by name
getMacroTokens :: [Macro] -> Name -> Maybe [Token]
getMacroTokens [] _ = Nothing
getMacroTokens ((name, _, tokens):macros) lookup_name = if name == lookup_name then Just tokens else getMacroTokens macros lookup_name

-- Get macro arity by name
getMacroArity :: [Macro] -> Name -> Maybe Arity
getMacroArity [] _ = Nothing
getMacroArity ((name, arity, _):macros) lookup_name = if name == lookup_name then Just arity else getMacroArity macros lookup_name

-- Get variable value by name
getVar :: [Variable] -> Name -> Maybe Value
getVar [] _ = Nothing
getVar ((name, value):variables) lookup_name = if name == lookup_name then Just value else getVar variables lookup_name

-- Set variable value by name
setVar :: [Variable] -> Name -> Value -> [Variable]
setVar [] name value = [(name, value)]
setVar ((name, value):variables) lookup_name replace_value
  | name == lookup_name = (name, replace_value):variables
  | otherwise           = (name, value) : setVar variables lookup_name replace_value