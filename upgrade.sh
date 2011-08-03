#!/bin/bash

set -o errexit
cd `dirname $0`

eval `./admin/ShowDBDefs`

echo `date` : Adding label code constraints
./admin/psql READWRITE < admin/sql/updates/20110801-label-code-validation.sql

echo `date` : Fixing edits_failed column
./admin/psql READWRITE < admin/sql/updates/20110725-rebuild-editor-stats.sql

echo `date` : Removing and preventing invalid attributes on links
./admin/psql READWRITE < ./admin/sql/updates/20110726-invalid-attributes.sql

echo `date` : Fixing sbontragers ISRC submissions
./admin/sql/updates/20110604-cleanup-sbontrager-isrc.pl

echo `date` : Done

# eof
