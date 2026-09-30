@echo off
rem ===========================================================================
rem  Install.bat - store where the pkg hub is, in PKG_DIR.
rem
rem  That is the whole job. It works out where it is (%~dp0, the folder the file
rem  sits in - which for the copy that ships is the hub itself: include\ beside
rem  lib\), and it stores that one path in PKG_DIR: in this shell right away, and
rem  in this user's environment (setx) so a shell opened later, reboot included,
rem  starts with it too.
rem
rem  It takes no arguments and sets nothing but PKG_DIR. INCLUDE, LIB, the
rem  architecture and the configuration are the consumer's business - every
rem  consumer reads them off PKG_DIR itself:
rem
rem    %PKG_DIR%\include\<member>              one include root per member
rem    %PKG_DIR%\lib\<member>\<arch>\<config>  the column it builds against
rem
rem  Nothing is stored before the folder has proven it is the hub: the layout
rem  above is the contract, and a misplaced copy must not leave a PKG_DIR behind
rem  that outlives the shell it was typed in. Re-running it from a newer unpack
rem  replaces the stored value; there is nothing to accumulate.
rem ===========================================================================

setlocal

rem  %~dp0 is where this file is, which - for the copy that ships - is the hub
rem  itself. It always ends in a backslash; drop it, so the stored path reads as
rem  the folder and a misplaced copy is recognisable in the message rather than
rem  in a doubled separator.
set "HUB=%~dp0"
set "HUB=%HUB:~0,-1%"

rem  The contract, checked in the order a consumer would meet it: the include
rem  tree, and beside it at least one staged column. Members are not enumerated
rem  here - which members exist is the hub's business and changes with it; that
rem  include\ and lib\ are there, and lib\ holds a <arch>\<config> column with
rem  libraries in it, is what makes the folder the hub and not some other folder
rem  that happens to hold an Install.bat.
if not exist "%HUB%\include\" goto not_the_hub
if not exist "%HUB%\lib\" goto not_the_hub

set "PKG_DIR=%HUB%"

rem  setx stores at most 1024 characters. A path can reach that only in a
rem  pathological layout, and half a path is worse than none - it would leave a
rem  PKG_DIR pointing into a folder that does not exist. So fail loudly instead
rem  of storing half of one.
if not "%PKG_DIR:~1024%"=="" goto too_long

setx PKG_DIR "%PKG_DIR%" >nul || goto persist_failed

rem  setx does not touch the shell it runs in, so the session's copy is set here.
endlocal & set "PKG_DIR=%HUB%"
exit /b 0

rem ------------------------------------------------------------------- helpers
:not_the_hub
echo Install.bat: there is no 'include' folder beside this file, so this is not
echo                the hub copy. Run the copy that sits inside the hub folder -
echo                the one whose neighbours are include\ and lib\, which is the
echo                file that ships in the artifact. This copy is at "%HUB%".
exit /b 1

:too_long
echo Install.bat: the hub path is past the 1024 characters setx can store, so
echo                nothing was stored. This shell has PKG_DIR="%PKG_DIR%";
echo                unpack the hub shallower and run this again.
exit /b 1

:persist_failed
echo Install.bat: setx could not store PKG_DIR.
exit /b 1
