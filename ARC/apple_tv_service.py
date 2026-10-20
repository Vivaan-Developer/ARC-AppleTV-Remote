#!/usr/bin/env python3
"""ARC 3.4: persistent pyatv connection, using atvremote's saved credentials.

Protocol: one JSON request per stdin line, one JSON event per stdout line.
The service stays alive until ARC quits. No subprocess is started per key press.
"""
import asyncio
import json
import sys


def emit(data):
    print(json.dumps(data), flush=True)


try:
    import pyatv
    from pyatv.storage.file_storage import FileStorage
except Exception as exc:
    emit({"event": "error", "message": "Cannot import Apple TV support: " + str(exc)})
    sys.exit(1)


class Service:
    def __init__(self):
        self.loop = asyncio.get_running_loop()
        self.storage = FileStorage.default_storage(self.loop)
        self.devices = {}
        self.selected = None
        self.atv = None
        self.connected = False
        self.pairing = None

    async def scan(self):
        emit({"event": "status", "message": "Searching for Apple TVs…"})
        # The same storage used by `atvremote wizard`, including its credentials.
        found = await pyatv.scan(self.loop, timeout=5, storage=self.storage)
        # Ignore devices without an Apple TV remote-control service.
        from pyatv.const import Protocol
        found = [conf for conf in found if conf.get_service(Protocol.Companion) or conf.get_service(Protocol.MRP)]
        self.devices = {str(i): conf for i, conf in enumerate(found)}
        self.selected = None
        await self.disconnect()
        emit({"event": "devices", "devices": [
            {"id": key, "name": conf.name, "address": str(conf.address)}
            for key, conf in self.devices.items()
        ]})

    async def disconnect(self):
        if self.atv is not None:
            try:
                self.atv.close()
            except Exception:
                pass
        self.atv = None
        self.connected = False

    async def connect(self):
        if self.selected is None:
            emit({"event": "error", "message": "Select an Apple TV first"})
            return False
        if self.atv is not None:
            return True
        emit({"event": "status", "message": "Connecting to Apple TV…"})
        try:
            self.atv = await asyncio.wait_for(
                pyatv.connect(self.selected, self.loop, storage=self.storage),
                timeout=15,
            )
            self.connected = True
            emit({"event": "connected", "name": self.selected.name})
            return True
        except Exception as exc:
            await self.disconnect()
            emit({"event": "error", "message": "Connection failed: " + str(exc)})
            return False

    async def command(self, name):
        mapping = {"previous": "skip_backward", "next": "skip_forward"}
        name = mapping.get(name, name)
        allowed = {
            "up", "down", "left", "right", "select", "menu", "home",
            "play_pause", "play", "pause", "skip_backward", "skip_forward",
            "volume_up", "volume_down", "turn_on", "turn_off",
        }
        if name not in allowed:
            emit({"event": "error", "message": "Unsupported command: " + str(name)})
            return
        if not await self.connect():
            return
        try:
            await asyncio.wait_for(getattr(self.atv.remote_control, name)(), timeout=8)
            emit({"event": "command", "ok": True})
        except Exception as exc:
            # The next press can establish a new connection if this one dropped.
            await self.disconnect()
            emit({"event": "error", "message": "Remote error: " + str(exc)})

    async def begin_pairing(self):
        if self.selected is None:
            emit({"event":"error","message":"Select an Apple TV first"})
            return
        await self.cancel_pairing()
        from pyatv.const import Protocol
        protocol = Protocol.Companion if self.selected.get_service(Protocol.Companion) else Protocol.MRP
        try:
            self.pairing = await pyatv.pair(self.selected, protocol, self.loop, storage=self.storage)
            await self.pairing.begin()
            emit({"event":"pairing_pin","message":"Enter the PIN shown on Apple TV (or enter a PIN on the TV if requested)."})
        except Exception as exc:
            await self.cancel_pairing()
            emit({"event":"error","message":"Pairing could not start: " + str(exc)})

    async def finish_pairing(self, pin):
        if self.pairing is None:
            emit({"event":"error","message":"Start pairing first"})
            return
        try:
            if not str(pin).isdigit():
                raise ValueError("PIN must contain digits")
            self.pairing.pin(int(pin))
            await self.pairing.finish()
            if not self.pairing.has_paired:
                raise RuntimeError("Apple TV did not confirm pairing. Try again.")
            await self.storage.save()
            emit({"event":"paired","message":"Paired successfully! Press Connect."})
        except Exception as exc:
            emit({"event":"error","message":"Pairing failed: " + str(exc)})
        finally:
            await self.cancel_pairing()

    async def cancel_pairing(self):
        if self.pairing is not None:
            try:
                await self.pairing.close()
            except Exception:
                pass
            self.pairing = None

    async def handle(self, msg):
        action = msg.get("action")
        if action == "scan":
            await self.scan()
        elif action == "select":
            await self.disconnect()
            self.selected = self.devices.get(str(msg.get("id")))
            emit({"event": "status", "message":
                  "Selected " + self.selected.name if self.selected else "Device not found"})
        elif action == "connect":
            await self.connect()
        elif action == "command":
            await self.command(msg.get("command", ""))
        elif action == "pair":
            await self.begin_pairing()
        elif action == "pair_pin":
            await self.finish_pairing(msg.get("pin", ""))
        elif action == "pair_cancel":
            await self.cancel_pairing()
            emit({"event":"status","message":"Pairing cancelled"})
        elif action == "disconnect":
            await self.disconnect()
            emit({"event": "disconnected"})


async def main():
    service = Service()
    await service.storage.load()
    emit({"event": "ready"})
    try:
        while True:
            line = await asyncio.to_thread(sys.stdin.readline)
            if not line:
                break
            try:
                await service.handle(json.loads(line))
            except Exception as exc:
                emit({"event": "error", "message": str(exc)})
    finally:
        await service.cancel_pairing()
        await service.disconnect()
        await service.storage.save()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except Exception as exc:
        emit({"event": "error", "message": "Service stopped: " + str(exc)})
        sys.exit(1)
