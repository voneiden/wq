(lang dune 3.11)

(name wq)

(generate_opam_files true)

(source
 (github username/reponame))

(authors "Matti Eiden")

(maintainers "Matti Eiden")

(license MIT)

(documentation https://url/to/documentation)

(package
 (name wq)
 (synopsis "A short synopsis")
 (description "A longer description")
 (depends ocaml dune caqti caqti-lwt caqti-driver-postgresql ppx_rapper ppx_rapper_lwt cmdliner)
 (tags
  (topics "to describe" your project)))

; See the complete stanza docs at https://dune.readthedocs.io/en/stable/dune-files.html#dune-project
