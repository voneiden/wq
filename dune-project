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
 (depends ocaml (dune (<= 3.11.0)) calendar caqti caqti-lwt caqti-driver-postgresql caqti-type-calendar ppx_rapper ppx_rapper_lwt cmdliner ppx_inline_test (ocamlformat :with-test) )
 (tags
  (topics "to describe" your project)))

; See the complete stanza docs at https://dune.readthedocs.io/en/stable/dune-files.html#dune-project
