#!/usr/bin/env python3
from argparse import REMAINDER, ArgumentParser, Namespace
import os
import sys
import subprocess
import shutil
from typing import Any

class ArgumentManager():
    """
    A class for managing command line arguments for the game launcher.
    """
    def __init__(self) -> None:
        self.parser = ArgumentParser(description="A script for launching games with optimizations.")
        self.parser.add_argument("-hdr", "--enable-hdr", action="store_true", help="Enable HDR mode.")
        self.parser.add_argument("-f", "--fullscreen", action="store_true", help="Launch the game in fullscreen mode.")
        self.parser.add_argument("--force-grab-cursor", action="store_true", help="Force grab the cursor in gamescope.")
        self.parser.add_argument("-nvidia", "--enable-proton-nvidia-flags", action="store_true", help="Enable Proton NVIDIA flags for better performance.")
        self.parser.add_argument("command_line", nargs=REMAINDER, help="The command and arguments to launch the game.")

    def parse_arguments(self) -> Namespace:
        return self.parser.parse_args()

class GameLauncher():
    """
    A class for optimizing the launching of games
    with the use of tools like gamescope, mangohud and gamemode.
    """
    def __init__(self, args: list[str],
                 enable_hdr: bool = False, enable_fullscreen: bool = False,
                 force_grab_cursor: bool = False,
                 enable_proton_nvidia_flags: bool = False) -> None:
        self.args: list[str] = args
        self.app_id: int = -1
        self.resolution: dict[str, int] = {
            "width": -1,
            "height": -1
        }

        self.refresh_rate: int = -1
        self.fullscreen_mode: bool = enable_fullscreen
        self.force_grab_cursor: bool = force_grab_cursor
        self.hdr_enabled: bool = enable_hdr
        self.enable_proton_nvidia_flags: bool = enable_proton_nvidia_flags

        self.gamescope_path = str(shutil.which("gamescope"))
        self.mangohud_path = str(shutil.which("mangohud"))
        self.gamemoderun_path = str(shutil.which("gamemoderun"))

        if self.gamescope_path == "None":
            raise FileNotFoundError("gamescope is not installed or not found in PATH.")
        if self.mangohud_path == "None":
            raise FileNotFoundError("mangohud is not installed or not found in PATH.")
        if self.gamemoderun_path == "None":
            raise FileNotFoundError("gamemoderun is not installed or not found in PATH.")

        self.is_wayland_available: bool = os.environ.get("XDG_SESSION_TYPE") == "wayland"
        self.is_gamescope_available: bool = True if self.gamescope_path else False
        self.is_mangohud_available: bool = True if self.mangohud_path else False
        self.is_gamemoderun_available: bool = True if self.gamemoderun_path else False

        for arg in args:
            if arg.startswith("AppId="):
                self.app_id = int(arg.split("=")[1])
                break

        self.CURRENT_USER: str = os.getlogin()
        self.CURRENT_PLATFORM: str = sys.platform.lower()

    def set_display_resolution(self, width: int, height: int) -> None:
        """
        Set the resolution to be used inside gamescope.
        Args:
            width (int): The desired width.
            height (int): The desired height.
        """
        self.resolution["width"] = width
        self.resolution["height"] = height

    def set_refresh_rate(self, refresh_rate: int) -> None:
        """
        Set the refresh rate to be used inside gamescope.
        Args:
            refresh_rate: int
        """

        if self.refresh_rate == -1:
            self.refresh_rate = refresh_rate

    def __set_hdr_flags(self, content_nits: int = 200,
                        itm_sdr_nits: int = 200,
                        itm_target_nits: int = 302) -> list[str]:
        """
        Set the HDR flags to be used inside gamescope.
        Returns:
            list[str]: The HDR flags.
        """
        hdr_flags:list[str] = [
            "--hdr-enabled",
            "--hdr-sdr-content-nits",
            "{0}".format(content_nits),
            "--hdr-itm-enabled",
            "--hdr-itm-sdr-nits",
            "{0}".format(itm_sdr_nits),
            "--hdr-itm-target-nits",
            "{0}".format(itm_target_nits)
        ]

        return hdr_flags

    def __set_environment_variables(self) -> list[str]:
        """
        Set the environment variables to be used inside gamescope.
        Returns:
            list[str]: The environment variables.
        """
        env_vars: list[str] = [
            "PROTON_ENABLE_NVAPI=1",
            "PROTON_ENABLE_NGX_UPDATER=1",
            "PROTON_ENABLE_WAYLAND=1",
            "PROTON_ENABLE_HDR=1",
            "DXVK_HDR=1",
            "DXVK_NVAPI_VKREFLEX=1",
            "PROTON_DLSS_UPGRADE=1"
        ]

        return env_vars

    def __build_cmdline(self, refresh_rate: int = 60,
                        resolution_width: int = 1920,
                        resolution_height: int = 1080) -> list[str]:
        command_line: list[str] = []

        self.set_refresh_rate(refresh_rate)
        self.set_display_resolution(resolution_width, resolution_height)

        if self.is_gamescope_available:
            command_line.append(self.gamescope_path)

            command_line.extend([
                "-W", str(self.resolution['width']),
                "-H", str(self.resolution['height'])
                ])

            command_line.extend([
                "-w", "3840",
                "-h", "2160"
            ])

            if not self.refresh_rate == -1:
                command_line.extend(["-r", str(self.refresh_rate)])

            if self.is_wayland_available:
                command_line.append("--expose-wayland")

            if self.hdr_enabled:
                for flag in self.__set_hdr_flags():
                    command_line.append(flag)

            if self.fullscreen_mode:
                command_line.append("--fullscreen")

            if self.force_grab_cursor:
                command_line.append("--force-grab-cursor")

            command_line.append("--immediate-flips")
            command_line.append("--")

        if self.enable_proton_nvidia_flags:
            command_line.append("env")
            for env_var in self.__set_environment_variables():
                command_line.append(env_var)

        if self.is_mangohud_available:
                command_line.append(self.mangohud_path)
                if self.app_id == 255710:
                    command_line.append("--dlsym")

        if self.is_gamemoderun_available:
            command_line.append(self.gamemoderun_path)

        command_line.extend(self.args)

        return command_line

    def __prepare(self) -> list[str]:
        """
        Prepare the command line for launching the game.
        Args:
        Raises:
            RuntimeError: If the platform is not supported.
            PermissionError: If the script is run as root.
        """
        if not self.CURRENT_PLATFORM == "linux":
            raise RuntimeError(f"Your platform '{self.CURRENT_PLATFORM}' is not supported.")

        if self.CURRENT_USER == "root":
            raise PermissionError("Do not run this script as root.")

        try:
            return self.__build_cmdline(refresh_rate=200,
                                        resolution_width=2560,
                                        resolution_height=1440)
        except Exception as e:
            raise e

    def run(self, show_debug_info: bool = False) -> int:
        """
        Run the game with the specified arguments.
        Returns:
            int: The exit code of the game process.
        """
        cmdline: list[str] = []
        exit_code: int = 0

        cmdline = self.__prepare()

        if show_debug_info:
            debug_info: dict[str, Any] = {
                "args": self.args,
                "app_id": self.app_id,
                "resolution": "{}x{}".format(self.resolution["width"],
                                             self.resolution["height"]),
                "refresh_rate": self.refresh_rate,
                "fullscreen_mode": self.fullscreen_mode,
                "force_grab_cursor": self.force_grab_cursor,
                "is_hdr_enabled": self.hdr_enabled,
                "is_wayland_available": self.is_wayland_available,
                "is_gamescope_available": self.is_gamescope_available,
                "is_mangohud_available": self.is_mangohud_available,
                "is_gamemoderun_available": self.is_gamemoderun_available,
            }

            for key, value in debug_info.items():
                print("{0}={1}".format(key, value))

            print(f"Running command: {' '.join(cmdline)}")

        try:
            process = subprocess.run(
                cmdline,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE
            )
            exit_code: int = process.returncode
            process.check_returncode()

        except Exception as e:
            raise e

        return exit_code

if __name__ == "__main__":
    if len(sys.argv[1:]) == 0:
        raise ValueError("No program was specified.")

    argument_manager = ArgumentManager().parse_arguments()

    launcher = GameLauncher(argument_manager.command_line,
                            enable_fullscreen=argument_manager.fullscreen,
                            force_grab_cursor=argument_manager.force_grab_cursor,
                            enable_hdr=argument_manager.enable_hdr,
                            enable_proton_nvidia_flags=argument_manager.enable_proton_nvidia_flags)
    launcher.run(show_debug_info=True)
