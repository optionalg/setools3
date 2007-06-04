/**
 *  @file
 *  Implementation of the sefs_fcfile class.
 *
 *  @author Jeremy A. Mowery jmowery@tresys.com
 *  @author Jason Tang jtang@tresys.com
 *
 *  Copyright (C) 2007 Tresys Technology, LLC
 *
 *  This library is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU Lesser General Public
 *  License as published by the Free Software Foundation; either
 *  version 2.1 of the License, or (at your option) any later version.
 *
 *  This library is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *  Lesser General Public License for more details.
 *
 *  You should have received a copy of the GNU Lesser General Public
 *  License along with this library; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
 */

#include <config.h>

#include "sefs_internal.hh"

#include <sefs/entry.hh>
#include <sefs/fcfile.hh>
#include <apol/util.h>
#include <qpol/genfscon_query.h>
#include <assert.h>
#include <ctype.h>
#include <errno.h>
#include <regex.h>
#include <stdio.h>

/******************** public functions below ********************/

static void fcfile_entry_free(void *elem)
{
	if (elem != NULL)
	{
		sefs_entry *entry = static_cast < sefs_entry * >(elem);
		delete entry;
	}
}

sefs_fcfile::sefs_fcfile(sefs_callback_fn_t msg_callback, void *varg) throw(std::bad_alloc):sefs_fclist(SEFS_FCLIST_TYPE_FCFILE,
													msg_callback, varg)
{
	_files = _entries = NULL;
	_mls_set = false;
	try
	{
		if ((_files = apol_vector_create(free)) == NULL)
		{
			throw std::bad_alloc();
		}
		if ((_entries = apol_vector_create(fcfile_entry_free)) == NULL)
		{
			throw std::bad_alloc();
		}
	}
	catch(...)
	{
		apol_vector_destroy(&_files);
		apol_vector_destroy(&_entries);
		throw;
	}
}

sefs_fcfile::sefs_fcfile(const char *file, sefs_callback_fn_t msg_callback, void *varg) throw(std::bad_alloc, std::invalid_argument,
											      std::
											      runtime_error):sefs_fclist
	(SEFS_FCLIST_TYPE_FCFILE, msg_callback, varg)
{
	_files = _entries = NULL;
	_mls_set = false;
	try
	{
		if ((_files = apol_vector_create_with_capacity(1, free)) == NULL)
		{
			throw std::bad_alloc();
		}
		if ((_entries = apol_vector_create(fcfile_entry_free)) == NULL)
		{
			throw std::bad_alloc();
		}
		if (appendFile(file) < 0)
		{
			throw std::runtime_error("Could not construct fcfile with the given file.");
		}
	}
	catch(...)
	{
		apol_vector_destroy(&_files);
		apol_vector_destroy(&_entries);
		throw;
	}
}

sefs_fcfile::sefs_fcfile(const apol_vector_t * files, sefs_callback_fn_t msg_callback, void *varg) throw(std::bad_alloc,
													 std::invalid_argument,
													 std::
													 runtime_error):sefs_fclist
	(SEFS_FCLIST_TYPE_FCFILE, msg_callback, varg)
{
	_files = _entries = NULL;
	_mls_set = false;
	try
	{
		if (files == NULL)
		{
			errno = EINVAL;
			throw std::invalid_argument(strerror(EINVAL));
		}
		if ((_files = apol_vector_create_with_capacity(apol_vector_get_size(files), free)) == NULL)
		{
			throw std::bad_alloc();
		}
		if ((_entries = apol_vector_create(fcfile_entry_free)) == NULL)
		{
			throw std::bad_alloc();
		}
		if (appendFileList(files) != apol_vector_get_size(files))
		{
			throw std::runtime_error("Could not construct fcfile with the given vector.");
		}
	}
	catch(...)
	{
		apol_vector_destroy(&_files);
		apol_vector_destroy(&_entries);
		throw;
	}
}

sefs_fcfile::~sefs_fcfile()
{
	apol_vector_destroy(&_files);
	apol_vector_destroy(&_entries);
}

apol_vector_t *sefs_fcfile::runQuery(sefs_query * query) throw(std::bad_alloc)
{
	apol_vector_t *v;
	if ((v = apol_vector_create(NULL)) == NULL)
	{
		throw std::bad_alloc();
	}
	if (query != NULL)
	{
		query->compile();
	}

	for (size_t i = 0; i < apol_vector_get_size(_entries); i++)
	{
		sefs_entry *e = static_cast < sefs_entry * >(apol_vector_get_element(_entries, i));
		if (query != NULL)
		{
			const struct sefs_context_node *context = e->_context;
			if (!str_compare(context->user, query->_user, query->_reuser, query->_regex))
			{
				continue;
			}
			if (!str_compare(context->role, query->_role, query->_rerole, query->_regex))
			{
				continue;
			}
			// FIX ME: check type & range & path

		}

		// if reached this point, then all criteria passed, so
		// accept the entry
		if (apol_vector_append(v, e) < 0)
		{
			apol_vector_destroy(&v);
			throw std::bad_alloc();
		}
	}
	return v;
}

bool sefs_fcfile::isMLS() const
{
	if (_mls_set)
	{
		return _mls;
	}
	return false;
}

int sefs_fcfile::appendFile(const char *file) throw(std::bad_alloc, std::invalid_argument, std::runtime_error)
{
	FILE *fc_file = NULL;
	char *line = NULL, *name_dup;
	size_t line_len = 0;
	size_t last_entry = apol_vector_get_size(_entries);
	int retval, error = 0;

	regex_t line_regex, context_regex;
	bool is_line_compiled = false;
	bool is_context_compiled = false;

	try
	{
		if (file == NULL)
		{
			error = EINVAL;
			SEFS_ERR("%s", strerror(EINVAL));
			throw std::invalid_argument(strerror(EINVAL));
		}

		fc_file = fopen(file, "r");
		if (!fc_file)
		{
			error = errno;
			SEFS_ERR("Unable to open file %s", file);
			throw std::runtime_error(strerror(error));
		}

		if ((name_dup = strdup(file)) == NULL)
		{
			error = errno;
			SEFS_ERR("%s", strerror(error));
			throw std::bad_alloc();
		}

		if (regcomp(&line_regex, "^([^[:blank:]]+)[[:blank:]]+(-.[[:blank:]]+)?([^-].+)$", REG_EXTENDED) != 0)
		{
			error = errno;
			SEFS_ERR("%s", strerror(error));
			throw std::bad_alloc();
		}
		is_line_compiled = true;

		if (regcomp(&context_regex, "^([^:]+):([^:]+):([^:]+):?(.*)$", REG_EXTENDED) != 0)
		{
			error = errno;
			SEFS_ERR("%s", strerror(error));
			throw std::bad_alloc();
		}
		is_context_compiled = true;

		while (!feof(fc_file))
		{
			if (getline(&line, &line_len, fc_file) == -1)
			{
				if (feof(fc_file))
				{
					break;
				}
				else
				{
					error = errno;
					SEFS_ERR("%s", strerror(error));
					throw std::bad_alloc();
				}
			}
			parse_line(name_dup, line, &line_regex, &context_regex);
		}

		if (apol_vector_append(_files, name_dup) < 0)
		{
			error = errno;
			SEFS_ERR("%s", strerror(error));
			throw std::bad_alloc();
		}
		name_dup = NULL;

		retval = 0;
	}
	catch(...)
	{
		// discard all entries that were read from this file_contexts
		size_t i = apol_vector_get_size(_entries);
		for (; i > last_entry; i--)
		{
			sefs_entry *e = static_cast < sefs_entry * >(apol_vector_get_element(_entries, i - 1));
			fcfile_entry_free(e);
			apol_vector_remove(_entries, i - 1);
		}
		retval = -1;
	}

	if (fc_file != NULL)
	{
		fclose(fc_file);
	}
	if (is_line_compiled)
	{
		regfree(&line_regex);
	}
	if (is_context_compiled)
	{
		regfree(&context_regex);
	}
	free(name_dup);
	free(line);
	errno = error;
	return retval;
}

size_t sefs_fcfile::appendFileList(const apol_vector_t * files)throw(std::bad_alloc, std::invalid_argument, std::runtime_error)
{
	size_t i;
	if (files == NULL)
	{
		errno = EINVAL;
		throw new std::invalid_argument(strerror(EINVAL));
	}
	for (i = 0; i < apol_vector_get_size(files); i++)
	{
		if (appendFile(static_cast < char *>(apol_vector_get_element(files, i))) < 0)
		{
			return i;
		}
	}
	return i;
}

const apol_vector_t *sefs_fcfile::fileList() const
{
	return _files;
}

/******************** private functions below ********************/

void sefs_fcfile::parse_line(const char *origin, const char *line, regex_t * line_regex,
			     regex_t * context_regex) throw(std::bad_alloc, std::runtime_error)
{
	int error = 0;

	char *s = strdup(line);
	char *path;

	if (s == NULL)
	{
		error = errno;
		SEFS_ERR("%s", strerror(error));
		throw std::bad_alloc();
	}

	apol_str_trim(s);
	if (s[0] == '#' || s[0] == '\0')
	{
		free(s);
		return;
	}

	try
	{
		const size_t nmatch = 5;
		regmatch_t pmatch[nmatch];

		if (regexec(line_regex, s, nmatch, pmatch, 0) != 0)
		{
			error = EIO;
			SEFS_ERR("fcfile line is not legal:\n%s", s);
			throw std::runtime_error(strerror(error));
		}

		assert(pmatch[1].rm_so == 0);
		s[pmatch[1].rm_eo] = '\0';
		if ((path = strdup(s)) == NULL)
		{
			SEFS_ERR("%s", strerror(errno));
			throw std::runtime_error(strerror(error));
		}
		if (apol_bst_insert_and_get(path_tree, (void **)&path, NULL) < 0)
		{
			free(path);
			SEFS_ERR("%s", strerror(errno));
			throw std::runtime_error(strerror(error));
		}

		uint32_t objclass;
		if (pmatch[2].rm_so != -1)
		{
			switch (s[pmatch[2].rm_so + 1])
			{
			case '-':
				objclass = QPOL_CLASS_FILE;
				break;
			case 'd':
				objclass = QPOL_CLASS_DIR;
				break;
			case 'c':
				objclass = QPOL_CLASS_CHR_FILE;
				break;
			case 'b':
				objclass = QPOL_CLASS_BLK_FILE;
				break;
			case 'p':
				objclass = QPOL_CLASS_FIFO_FILE;
				break;
			case 'l':
				objclass = QPOL_CLASS_LNK_FILE;
				break;
			case 's':
				objclass = QPOL_CLASS_SOCK_FILE;
				break;
			default:
				error = EIO;
				SEFS_ERR("%s", "Invalid file context object class.");
				throw std::runtime_error(strerror(error));
			}
		}
		else
		{
			// no object class explicitly given
			objclass = QPOL_CLASS_ALL;
		}

		assert(pmatch[3].rm_so != -1);
		char *context_str = s + pmatch[3].rm_so;
		char *user, *role, *type, *range;

		if (strcmp(context_str, "<<none>>") == 0)
		{
			user = role = type = range = "";
		}
		else
		{
			if (regexec(context_regex, context_str, nmatch, pmatch, 0) != 0)
			{
				error = EIO;
				SEFS_ERR("fcfile context is not legal:\n%s", context_str);
				throw std::runtime_error(strerror(error));
			}

			assert(pmatch[1].rm_so == 0);
			context_str[pmatch[1].rm_eo] = '\0';
			user = context_str;

			assert(pmatch[2].rm_so != -1);
			context_str[pmatch[2].rm_eo] = '\0';
			role = context_str + pmatch[2].rm_so;

			assert(pmatch[3].rm_so != -1);
			context_str[pmatch[3].rm_eo] = '\0';
			type = context_str + pmatch[3].rm_so;

			range = NULL;
			if (pmatch[4].rm_so != -1)
			{
				range = context_str + pmatch[4].rm_so;
			}
		}
		if (range != NULL & range[0] != '\0')
		{
			if (_mls_set && !_mls)
			{
				error = EIO;
				SEFS_ERR("fcfile context is MLS, but fcfile is not:\n%s", context_str);
				throw std::runtime_error(strerror(error));
			}
			_mls = true;
			_mls_set = true;
		}
		else
		{
			if (_mls_set && !_mls && strcmp(context_str, "<<none>>") != 0)
			{
				error = EIO;
				SEFS_ERR("fcfile context is not MLS, but fcfile is:\n%s", context_str);
				throw std::runtime_error(strerror(error));
			}
			_mls = true;
			_mls_set = false;
		}
		struct sefs_context_node *context = getContext(user, role, type, range);
		sefs_entry *entry = new sefs_entry(this, context, objclass, path, origin);

		if (apol_vector_append(_entries, static_cast < void *>(entry)) < 0)
		{
			error = errno;
			delete entry;
			SEFS_ERR("%s", strerror(error));
			throw std::bad_alloc();
		}
	}

	catch(...)
	{
		free(s);
		errno = error;
		throw;
	}

	free(s);
}

/******************** C functions below ********************/

sefs_fclist_t *sefs_fcfile_create(sefs_callback_fn_t msg_callback, void *varg)
{
	sefs_fclist *fclist;
	try
	{
		fclist = new sefs_fcfile(msg_callback, varg);
	}
	catch(...)
	{
		errno = ENOMEM;
		return NULL;
	}
	return fclist;
}

sefs_fclist_t *sefs_fcfile_create_from_file(const char *file, sefs_callback_fn_t msg_callback, void *varg)
{
	sefs_fclist *fclist;
	try
	{
		fclist = new sefs_fcfile(file, msg_callback, varg);
	}
	catch(...)
	{
		errno = ENOMEM;
		return NULL;
	}
	return fclist;
}

sefs_fclist_t *sefs_fcfile_create_from_file_list(const apol_vector_t * files, sefs_callback_fn_t msg_callback, void *varg)
{
	sefs_fclist *fclist;
	try
	{
		fclist = new sefs_fcfile(files, msg_callback, varg);
	}
	catch(...)
	{
		errno = ENOMEM;
		return NULL;
	}
	return fclist;
}

int sefs_fcfile_append_file(sefs_fcfile_t * fcfile, const char *file)
{
	if (fcfile == NULL)
	{
		errno = EINVAL;
		return -1;
	}
	try
	{
		fcfile->appendFile(file);
	}
	catch(...)
	{
		return -1;
	}
	return 0;
}

size_t sefs_fcfile_append_file_list(sefs_fcfile_t * fcfile, const apol_vector_t * files)
{
	if (fcfile == NULL)
	{
		errno = EINVAL;
		return 0;
	}
	return fcfile->appendFileList(files);
}

const apol_vector_t *sefs_fcfile_get_file_list(sefs_fcfile_t * fcfile)
{
	if (fcfile == NULL)
	{
		errno = EINVAL;
		return NULL;
	}
	return fcfile->fileList();
}