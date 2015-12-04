{-# LANGUAGE BangPatterns #-}
{-# LANGUAGE CPP          #-}

-- |
-- Module      : Data.Binary.Serialise.CBOR.Class
-- Copyright   : (c) Duncan Coutts 2015
-- License     : BSD3-style (see LICENSE.txt)
--
-- Maintainer  : duncan@community.haskell.org
-- Stability   : experimental
-- Portability : non-portable (GHC extensions)
--
-- The @'Serialise'@ class allows you to encode a given type into a
-- CBOR object, or decode a CBOR object into the user-specified type.
--
module Data.Binary.Serialise.CBOR.Class
  ( -- * The Serialise class
    Serialise(..)
  ) where

import           Data.Int
import           Data.Monoid
import           Data.Version
import           Data.Word

import qualified Data.ByteString                     as BS
import qualified Data.Text                           as Text

-- TODO: more instances
--import qualified Data.Array                          as Array
--import qualified Data.Array.Unboxed                  as UArray
--import qualified Data.ByteString                     as BS.Lazy
--import qualified Data.Map                            as Map
--import qualified Data.Sequence                       as Sequence
--import qualified Data.Set                            as Set
--import qualified Data.Text.Lazy                      as Text.Lazy

import           Data.Time                           (UTCTime (..))
#if MIN_VERSION_time(1,5,0)
import           Data.Time.Format                    (defaultTimeLocale,
                                                      formatTime, parseTimeM)
#else
import           Data.Time.Format                    (formatTime, parseTime)
import           System.Locale                       (defaultTimeLocale)
#endif

import           Prelude                             hiding (decodeFloat,
                                                      encodeFloat)

import           Data.Binary.Serialise.CBOR.Decoding
import           Data.Binary.Serialise.CBOR.Encoding

--------------------------------------------------------------------------------
-- The Serialise class

-- | Types that are instances of the @'Serialise'@ class allow values
-- to be quickly encoded or decoded directly to a CBOR representation,
-- for object transmission or storage.
class Serialise a where
    {-# MINIMAL encode, decode #-}

    -- | Definition for encoding a given type into a binary
    -- representation, using the @'Encoding'@ @'Monoid'@.
    encode  :: a -> Encoding

    -- | Definition of a given @'Decoder'@ for a type.
    decode  :: Decoder a

    -- | Utility to support specialised encoding for some list type -
    -- used for @'Char'@/@'String'@ instances in this package.
    encodeList :: [a] -> Encoding
    encodeList = defaultEncodeList

    -- | Utility to support specialised decoding for some list type -
    -- used for @'Char'@/@'String'@ instances in this package.
    decodeList :: Decoder [a]
    decodeList = defaultDecodeList

--------------------------------------------------------------------------------
-- Special list business

instance Serialise a => Serialise [a] where
    encode = encodeList
    decode = decodeList

defaultEncodeList :: Serialise a => [a] -> Encoding
defaultEncodeList [] = encodeListLen 0
defaultEncodeList xs = encodeListLenIndef
                    <> foldr (\x r -> encode x <> r) encodeBreak xs

defaultDecodeList :: Serialise a => Decoder [a]
defaultDecodeList = do
    mn <- decodeListLenOrIndef
    case mn of
      Nothing -> decodeSequenceLenIndef (flip (:)) [] reverse   decode
      Just n  -> decodeSequenceLenN     (flip (:)) [] reverse n decode


--------------------------------------------------------------------------------
-- Primitive instances

instance Serialise () where
    encode = const encodeNull
    decode = decodeNull

instance Serialise Bool where
    encode = encodeBool
    decode = decodeBool

instance Serialise Int where
    encode = encodeInt
    decode = decodeInt

instance Serialise Int64 where
    encode = encodeInt64
    decode = decodeInt64

instance Serialise Word where
    encode = encodeWord
    decode = decodeWord

instance Serialise Word64 where
    encode = encodeWord64
    decode = decodeWord64

instance Serialise Integer where
    encode = encodeInteger
    decode = decodeInteger

instance Serialise Float where
    encode = encodeFloat
    decode = decodeFloat

instance Serialise Double where
    encode = encodeDouble
    decode = decodeDouble

instance Serialise Char where
    encode c = encodeString (Text.singleton c)
    decode = do t <- decodeString
                if Text.length t == 1
                  then return $! Text.head t
                  else fail "expected a single char, found a string"

    -- For [Char]/String we have a special encoding
    encodeList cs = encodeString (Text.pack cs)
    decodeList    = do txt <- decodeString
                       return (Text.unpack txt) -- unpack lazily

instance Serialise Text.Text where
    encode = encodeString
    decode = decodeString

instance Serialise BS.ByteString where
    encode = encodeBytes
    decode = decodeBytes


--------------------------------------------------------------------------------
-- Structure instances

instance (Serialise a, Serialise b) => Serialise (a,b) where
    encode (a,b) = encodeListLen 2
                <> encode a
                <> encode b
    decode = do decodeListLenOf 2
                !x <- decode
                !y <- decode
                return (x, y)

instance (Serialise a, Serialise b, Serialise c) => Serialise (a,b,c) where
    encode (a,b,c) = encodeListLen 3
                  <> encode a
                  <> encode b
                  <> encode c

    decode = do decodeListLenOf 3
                !x <- decode
                !y <- decode
                !z <- decode
                return (x, y, z)

instance Serialise a => Serialise (Maybe a) where
    encode Nothing  = encodeListLen 0
    encode (Just x) = encodeListLen 1 <> encode x

    decode = do n <- decodeListLen
                case n of
                  0 -> return Nothing
                  1 -> do !x <- decode
                          return (Just x)
                  _ -> fail "unknown tag"

instance (Serialise a, Serialise b) => Serialise (Either a b) where
    encode (Left  x) = encodeListLen 2 <> encodeWord 0 <> encode x
    encode (Right x) = encodeListLen 2 <> encodeWord 1 <> encode x

    decode = do decodeListLenOf 2
                t <- decodeWord
                case t of
                  0 -> do !x <- decode
                          return x
                  1 -> do !x <- decode
                          return x
                  _ -> fail "unknown tag"

--------------------------------------------------------------------------------
-- Misc base package instances

instance Serialise Version where
    encode (Version ns ts) = encodeListLen 3
                          <> encodeWord 0 <> encode ns <> encode ts
    decode = do
      len <- decodeListLen
      tag <- decodeWord
      case tag of
        0 | len == 3
          -> do !x <- decode
                !y <- decode
                return (Version x y)
        _ -> fail "unexpected tag"

--------------------------------------------------------------------------------
-- Time instances
--
-- CBOR has some special encodings for times/timestamps

instance Serialise UTCTime where
    encode d = encodeTag 0
            <> encode (formatUTCrfc3339 d)

    decode = do
      tag <- decodeTag
      case tag of
        0 -> do str <- decodeString
                case parseUTCrfc3339 (Text.unpack str) of
                  Just t  -> return $! forceUTCTime t
                  Nothing -> fail "Could not parse RFC3339 date"
        _ -> fail "Expected timestamp (tag 0 or 1)"


formatUTCrfc3339 :: UTCTime -> String
parseUTCrfc3339  :: String -> Maybe UTCTime

-- Format UTC as timezone 'Z' but on parsing accept 'Z' or any numeric offset
formatUTCrfc3339 = formatTime       defaultTimeLocale "%Y-%m-%dT%H:%M:%S%QZ"
#if MIN_VERSION_time(1,5,0)
parseUTCrfc3339  = parseTimeM False defaultTimeLocale "%Y-%m-%dT%H:%M:%S%Q%Z"
#else
parseUTCrfc3339  = parseTime        defaultTimeLocale "%Y-%m-%dT%H:%M:%S%Q%Z"
#endif

-- UTCTime has an unnecessarily lazy representation, and the parsing is lazy
forceUTCTime :: UTCTime -> UTCTime
forceUTCTime t@(UTCTime !_day !_daytime) = t
