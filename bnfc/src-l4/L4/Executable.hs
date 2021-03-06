-- Program to test parser, automatically generated by BNF Converter.

module L4.Executable where

import System.Environment ( getArgs )
import System.Exit        ( exitFailure, exitSuccess )
import Control.Monad      ( when )

import Text.Pretty.Simple
import qualified Data.Text.Lazy as T
import LexL    ( Token )
import ParL    ( pTops, myLexer )
import SkelL   ()
import PrintL  ( printTree )
import AbsL    ( Tops(..), Rule(..), RuleBody(..), MatchVars(..), Toplevels(..) )
import LayoutL ( resolveLayout )
import ToGraphViz
import L4
import ToGF (bnfc2str)
import PGF (PGF, readPGF)

type Err = Either String
type ParseFun a = [Token] -> Err a

myLLexer = resolveLayout True . myLexer

type Verbosity = Int

putStrV :: Verbosity -> String -> IO ()
putStrV v s = when (v > 1) $ putStrLn s

runFile :: Verbosity -> PGF -> ParseFun Tops -> FilePath -> IO ()
runFile v gr p f = putStrLn f >> readFile f >>= run v gr p

run :: Verbosity -> PGF -> ParseFun Tops -> String -> IO ()
run v gr p s = case p ts of
    Left s -> do
      putStrLn "\nParse              Failed...\n"
      putStrV v "Tokens:"
      putStrV v $ show ts
      putStrLn s
      exitFailure
    Right tree -> do
      putStrLn "\nParse Successful!"
      showTree gr v tree

      exitSuccess
  where
  ts = myLLexer s


simpleParseTree :: String  -> Err Tops
simpleParseTree = pTops . myLLexer

prettyPrintParseTree :: String -> Either String T.Text
prettyPrintParseTree = fmap pShowNoColor . simpleParseTree

showTree :: PGF -> Int -> Tops -> IO ()
showTree gr v tree0
 = let tree = rewriteTree tree0 in do
      printMsg "Abstract Syntax" $ T.unpack (pShowNoColor tree)
      printMsg "Linearized tree" $ printTree tree
      printMsg "In English" $ bnfc2str gr tree
      let ruleList = getRules tree
      printMsg "Just the Names" $ unlines $ showRuleName <$> ruleList
      printMsg "Dictionary of Name to Rule" $ T.unpack (pShow $ nameList ruleList)
      printMsg "Rule to Exit" $ T.unpack (pShow $ (\r -> (showRuleName r, ruleExits r)) <$> ruleList)
      printMsg "As Graph" ""
      printGraph ruleList
      printMsg "As Dotfile" ""
      putStrLn $ showDot ruleList
      writeFile "graph.dot" (showDot ruleList)
  where
    printMsg msg result = putStrV v $ "\n[" ++ msg ++ "]\n\n" ++ result


rewriteTree :: Tops -> Tops
rewriteTree (Toplevel tops) = Toplevel $ do
  (ToplevelsRule r@(Rule rdef rname asof metalimb rulebody)) <- tops
  ToplevelsRule <$> case rulebody of
    RMatch mvs -> do
      (MatchVars23 innerRule) <- mvs
      rewrite innerRule
    otherwise -> rewrite r


usage :: IO ()
usage = do
  putStrLn $ unlines
    [ "usage: Call with one of the following argument combinations:"
    , "  --help          Display this help message."
    , "  (no arguments)  Parse stdin verbosely."
    , "  (files)         Parse content of files verbosely."
    , "  -s (files)      Silent mode. Parse content of files silently."
    ]
  exitFailure

main :: IO ()
main = do
  args <- getArgs
  gr <- readPGF "src-l4/Top.pgf"
  case args of
    ["--help"] -> usage
    [] -> getContents >>= run 2 gr pTops
    "-s":fs -> mapM_ (runFile 0 gr pTops) fs
    fs -> mapM_ (runFile 2 gr pTops) fs
