#!/usr/bin/env bash

# An evil script that protects our repository against unwanted
# changes. For now, it just makes sure that british spelling is
# preserved for the user-facing API.
#
# This script alone is under the Apache 2.0 license. Thanks to
# Phabricator for the sweet ASCII art.

set e
unset CDPATH

function onoes {
  echo '+-----------------------------------------------------------------+'
  echo '|      * * * PATCH REJECTED BY EVIL DRAGON BUREAUCRATS * * *      |'
  echo '|            * * * YOU MUST USE BRITISH SPELLING * * *            |'
  echo '+-----------------------------------------------------------------+'
  echo '            \'
  echo '             \                    ^    /^'
  echo '              \                  / \  // \'
  echo '               \   |\___/|      /   \//  .\'
  echo '                \  /V  V  \__  /    //  | \ \           *----*'
  echo '                  /     /  \/_/    //   |  \  \          \   |'
  echo '                  @___@`    \/_   //    |   \   \         \/\ \'
  echo '                     |       \/_ //     |    \    \         \  \'
  echo '                 )   |        \///      |     \     \       |  |'
  echo '                ((   |__/   (  //       |      \     _\     |  /'
  echo '               \~~/)/,_ _ _/  ) ; -.    |    _ _\.-~       /   /'
  echo '                == ,-}        _      *-.|.-~-.           .~    ~'
  echo '  \     \__/        `/\      /                 ~-. _ .-~      /'
  echo '   \____(Oo)           *.   }            {                   /'
  echo '   (    (--)          .----~-.\        \-`                 .~'
  echo '   //__\\\\  \ DENIED!  ///.----..<        \             _ -~'
  echo '  //    \\\\               ///-._ _ _ _ _ _ _{^ - - - - ~'
  echo ''
}

CHECK=`git grep -i serialize           | \
       grep -v "instance Serialize"    | \
       grep -v "instance (Serialize"   | \
       grep -v "Data.Serialize"        | \
       grep -v "Data.Vector.Serialize" | \
       grep -v "Deserialized type: "   | \
       grep -v "git grep"`

if [[ ! -z "${CHECK}" ]]; then
  onoes
  echo 'The dragon saw you say:'
  echo ''
  echo "  $CHECK"
  echo ''
  echo "and got angry. Don't do that!"

  exit 1;
else
  echo "OK: the dragon bureaucrat is happy"
fi
