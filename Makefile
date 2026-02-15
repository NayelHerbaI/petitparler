CC      := cc
CFLAGS  := -Wall -Wextra -Werror

NAME    := server client

OBJDIR  := obj

SRCS_SERVER := server.c server_utils.c server_handler.c utils.c
SRCS_CLIENT := client.c client_ack.c client_send.c utils.c

OBJS_SERVER := $(SRCS_SERVER:%.c=$(OBJDIR)/%.o)
OBJS_CLIENT := $(SRCS_CLIENT:%.c=$(OBJDIR)/%.o)

all: $(NAME)

server: $(OBJS_SERVER)
	$(CC) $(CFLAGS) $(OBJS_SERVER) -o $@

client: $(OBJS_CLIENT)
	$(CC) $(CFLAGS) $(OBJS_CLIENT) -o $@

$(OBJDIR)/%.o: %.c | $(OBJDIR)
	$(CC) $(CFLAGS) -c $< -o $@

$(OBJDIR):
	mkdir -p $(OBJDIR)

clean:
	rm -rf $(OBJDIR)

fclean: clean
	rm -f $(NAME)

re: fclean all

.PHONY: all clean fclean re
