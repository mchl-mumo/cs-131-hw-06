module NameSpec where

import PiqParser
import TestUtilities
import Test.Hspec


spec :: Spec
spec = describe "Part 1: names and keywords" $ do

    describe "Step 1.1: reserved words" $ do
        it "every word in reservedWords is reserved" $
            filter (not . isReserved) reservedWords `shouldBe` []
        it "ordinary names are not reserved" $
            filter isReserved ["x", "size", "dotty", "upper", "forward"] `shouldBe` []
        it "reserved words are lowercase: Dot is not reserved" $
            isReserved "Dot" `shouldBe` False

    describe "Step 1.2: keywords" $ do
        parsesTo (parse (keyword "dot")) "dot"     "dot"
        parsesTo (parse (keyword "dot")) "   dot"  "dot"
        parsesTo (parse (keyword "for")) "for"     "for"
        failsToParse (parse (keyword "dot")) "dotty"      -- a whole word, not the start of one
        failsToParse (parse (keyword "dot")) "square"
        failsToParse (parse (keyword "for")) "forward"

    describe "Step 1.3: names" $ do
        parsesTo (parse name) "size"     "size"
        parsesTo (parse name) "x2"       "x2"
        parsesTo (parse name) "starGap"  "starGap"
        parsesTo (parse name) "  gap"    "gap"
        parsesTo (parse name) "upper"    "upper"      -- starts with "up", but is not "up"
        parsesTo (parse name) "Dot"      "Dot"        -- names are case-sensitive
        failsToParse (parse name) "circle"
        failsToParse (parse name) "left"
        failsToParse (parse name) "for"
        failsToParse (parse name) "2x"
