#include <ctype.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <assert.h>

#include "ast.h"
#include "shared.h"
#include "function.h"

// register const char **stream;

static char peek(const char **stream) {
	return **stream;
}

static void advance(const char **stream) {
	++(*stream);
}

static char next(const char **stream) {
	return *((*stream)++);
}

static void strip_stream(const char **stream) {
	char c;

	while (1) {
		c = peek(stream);

		switch (c) {
		case '#':
			do {
				c = next(stream);
			} while (c != '\0' && c != '\n');

			continue;

		case '(':
		case ')':
		case '[':
		case ']':
		case '{':
		case '}':
		case ':':
			break;

		default:
			if (!isspace(c)) {
				return;
			}
		}

		advance(stream);
	}
}


static struct kn_ast_t kn_ast_parse_integer(const char **stream) {
	assert(isdigit(peek(stream)));

	kn_integer_t integer = 0;

	do {
		integer *= 10;
		integer += next(stream) - '0';
	} while (isdigit(peek(stream)));

	return (struct kn_ast_t) {
		.kind = KN_TT_VALUE,
		.value = kn_value_new_integer(integer)
	};
}

static int isident(char c) {
	return islower(c) || isdigit(c) || c == '_';
}

static struct kn_ast_t kn_ast_parse_identifier(const char **stream) {
	assert(isident(peek(stream)));

	size_t capacity = 8;
	size_t length = 0;
	char *identifier = xmalloc(capacity);

	do {
		identifier[length++] = next(stream);

		if (length == capacity) {
			identifier = xrealloc(identifier, capacity *= 2);
		}
	} while (isident(peek(stream)));

	identifier[length++] = '\0';
	identifier = xrealloc(identifier, length);

	return (struct kn_ast_t) {
		.kind = KN_TT_IDENTIFIER,
		.identifier = identifier
	};
}

static struct kn_ast_t kn_ast_parse_string(const char **stream) {
	assert(peek(stream) == '"' || peek(stream) == '\'');

	size_t length = 0;
	size_t capacity = 16;
	char *string = xmalloc(capacity);
	char c;

	for (char quote = next(stream); quote != (c = next(stream));) {
		string[length++] = c;

		if (c == '\0') {
			die("unterminated quote encountered: %c%s\n",
				quote, string);
		}

		if (length == capacity) {
			string = xrealloc(string, capacity *= 2);
		}
	}

	string[length++] = '\0';
	string = xrealloc(string, length); // remove unused capacity

	return (struct kn_ast_t) {
		.kind = KN_TT_VALUE,
		.value = kn_value_new_string(kn_string_new(string))
	};
}

static struct kn_ast_t kn_ast_parse_function(const char **stream) {
	char name = next(stream);

	// strip trailing keywords.
	if (isupper(name)) {
		while (isupper(peek(stream))) {
			advance(stream);
		}
	}

	const struct kn_function_t *function = kn_fn_fetch(name);

	if (function == NULL) {
		die("unknown function '%c' encountered.", name);
	}

	size_t arity = function->arity;

	struct kn_ast_t ast = (struct kn_ast_t) {
		.kind = KN_TT_FUNCTION,
		.function = function,
		.arguments = xmalloc(arity * sizeof(struct kn_ast_t))
	};

	for (size_t i = 0; i < arity; ++i) {
		ast.arguments[i] = kn_ast_parse(stream);
	}

	return ast;
}

struct kn_ast_t kn_ast_parse(const char **stream) {
	strip_stream(stream);
	char peeked = peek(stream);

	if (isdigit(peeked)) {
		return kn_ast_parse_integer(stream);
	}

	if (isident(peeked)) {
		return kn_ast_parse_identifier(stream);
	}

	if (peeked == '\'' || peeked == '"') {
		return kn_ast_parse_string(stream);
	}

	if (isupper(peeked) || ispunct(peeked)) {
		return kn_ast_parse_function(stream);
	}

	if (peeked == '\0') {
		die("unexpected eof; expected an expression.");
	} else {
		die("unknown token start '%c'", peeked);
	}
}

struct kn_value_t kn_ast_run(const struct kn_ast_t *ast) {
	switch (ast->kind) {
	case KN_TT_VALUE:
		return kn_value_clone(&ast->value);

	case KN_TT_IDENTIFIER: {
		const struct kn_value_t *retptr = kn_env_get(ast->identifier);

		if (retptr == NULL) {
			die("unknown identifier '%s'", ast->identifier);
		}

		return kn_value_clone(retptr);
	}

	case KN_TT_FUNCTION:
		return (ast->function->func)(ast->arguments);

	default:
		bug("unknown kind '%d'");
	}
}

struct kn_ast_t kn_ast_clone(const struct kn_ast_t *ast) {
	struct kn_ast_t ret = (struct kn_ast_t) {
		.kind = ast->kind
	};

	switch (ret.kind) {
	case KN_TT_VALUE:
		ret.value = kn_value_clone(&ast->value);
		break;

	case KN_TT_IDENTIFIER: {
		char *identifier = strdup((char *) ast->identifier);

		VERIFY_NOT_NULL(identifier, "unable to duplicate identifier");

		ret.identifier = identifier;
		break;
	}

	case KN_TT_FUNCTION: {
		ret.function = ast->function;
		size_t arity = ret.function->arity;

		ret.arguments = xmalloc(arity * sizeof(struct kn_ast_t));

		for (size_t i = 0; i < arity; i++) {
			ret.arguments[i] = kn_ast_clone(&ast->arguments[i]);
		}

		break;
	}

	default:
		bug("unknown kind '%d'", ast->kind);
	}

	return ret;
}

void kn_ast_free(struct kn_ast_t *ast) {
	switch (ast->kind) {
	case KN_TT_VALUE:
		kn_value_free(&ast->value);
		break;

	case KN_TT_IDENTIFIER:
		free((void *) ast->identifier);
		break;

	case KN_TT_FUNCTION:
		for (size_t i = 0; i < ast->function->arity; ++i) {
			kn_ast_free(&ast->arguments[i]);
		}

		free((void *) ast->arguments);
		break;

	default:
		bug("unknown kind '%d'", ast->kind);
	}
}
