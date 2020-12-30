#include "shared.h"
#include "knight.h"
#include "env.h"

#ifndef KNIGHT_ENV_INIT_SIZE
#define KNIGHT_ENV_INIT_SIZE 128
#endif

void kn_init(void) {
	static bool INITIALIZED = false;

	if (INITIALIZED) {
		return;
	}

	INITIALIZED = true;

	kn_env_init(KNIGHT_ENV_INIT_SIZE);
}

struct kn_value_t kn_run(const char *stream) {
	DBG("");
	struct kn_ast_t ast = kn_ast_parse(&stream);
	DBG("");
	struct kn_value_t ret = kn_ast_run(&ast);
	DBG("");

	kn_ast_free(&ast);

	return ret;
}
