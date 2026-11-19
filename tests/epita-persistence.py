"""Régressions : migration sans perte et changement de poste avec le même AFS."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("prepare", Path(__file__).parents[1] / "epita/prepare.py")
prepare = importlib.util.module_from_spec(spec)
spec.loader.exec_module(prepare)


class PersistenceTests(unittest.TestCase):
    def test_existing_config_and_pictures_survive_second_machine(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            afs = root / "afs"
            afs.mkdir()
            for machine in ("a", "b"):
                home = root / machine
                home.mkdir()
                (home / "afs").symlink_to(afs)
            a, b = root / "a", root / "b"
            (a / ".config/nc").mkdir(parents=True)
            (a / ".config/nc/reglages.conf").write_text("STYLE=nord\n")
            (a / "Pictures").mkdir()
            (a / "Pictures/personal.jpg").write_bytes(b"personal image")
            migration = prepare.PersistentHome(a)
            migration.link(".config/nc", True)
            migration.link("Pictures", True)
            self.assertTrue((a / "Pictures").is_symlink())
            migration.link("Pictures", True)
            (b / ".config/nc").mkdir(parents=True)
            (b / ".config/nc/reglages.conf").write_text("STYLE=local-conflict\n")
            (b / ".config/nc/new.conf").write_text("local-only")
            second = prepare.PersistentHome(b)
            second.link(".config/nc", True)
            second.link("Pictures", True)
            self.assertEqual((b / ".config/nc/reglages.conf").read_text(), "STYLE=nord\n")
            self.assertEqual((second.backup / ".config/nc/reglages.conf").read_text(), "STYLE=local-conflict\n")
            self.assertEqual((b / ".config/nc/new.conf").read_text(), "local-only")
            self.assertEqual((b / "Pictures/personal.jpg").read_bytes(), b"personal image")

    def test_atomic_replacement_relinks_file_without_losing_backup(self):
        with tempfile.TemporaryDirectory() as temporary:
            home = Path(temporary)
            home.joinpath("afs").mkdir()
            rc = home / ".zshrc"
            rc.write_text("old")
            migration = prepare.PersistentHome(home)
            migration.link(".zshrc", False)
            new = home / ".zshrc.new"
            new.write_text("installed")
            new.replace(rc)
            migration.link(".zshrc", False, prefer_local=True)
            self.assertTrue(rc.is_symlink())
            self.assertEqual(rc.read_text(), "installed")

    def test_readonly_source_link_is_copied_and_becomes_writable(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            home = root / "home"
            home.mkdir()
            (home / "afs").mkdir()
            source = root / "store"
            source.mkdir()
            (source / "config").write_text("source")
            (source / "config").chmod(0o444)
            (home / "Pictures").symlink_to(source)
            prepare.PersistentHome(home).link("Pictures", True)
            (home / "Pictures/config").write_text("changed")
            self.assertEqual((source / "config").read_text(), "source")


if __name__ == "__main__":
    unittest.main()
