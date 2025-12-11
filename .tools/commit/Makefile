NAME        := auto_commit
CC          := cc
CFLAGS      := -Wall -Wextra -Werror -I includes

SRC_DIR     := srcs
LIB_DIR     := libraries
OBJ_DIR     := .objs

##
## ┌──────────────────┐
## │ SOURCE DISCOVERY │
## └──────────────────┘
##

SRC_FILES   := $(shell find $(SRC_DIR) -type f -name "*.c")
LIB_SRC     := $(shell find $(LIB_DIR) -type f -name "*.c")
SRCS        := $(SRC_FILES) $(LIB_SRC)
OBJS        := $(SRCS:%=$(OBJ_DIR)/%.o)

##
## ┌───────┐
## │ RULES │
## └───────┘
##

all: $(NAME)

$(NAME): $(OBJS)
	@printf "[LD] %s\n" "$(NAME)"
	@$(CC) $(CFLAGS) $(OBJS) -o $(NAME)

$(OBJ_DIR)/%.c.o: %.c
	@mkdir -p $(dir $@)
	@printf "[CC] %s\n" "$<"
	@$(CC) $(CFLAGS) -c $< -o $@

##
## ┌───────┐
## │ CLEAN │
## └───────┘
##

clean:
	@printf "[CLEAN] removing object files\n"
	@rm -rf $(OBJ_DIR)

fclean: clean
	@printf "[FCLEAN] removing binary\n"
	@rm -f $(NAME)

re: fclean all

##
## ┌───────┐
## │ PHONY │
## └───────┘
##

.PHONY: all clean fclean re
