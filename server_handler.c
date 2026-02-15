/* ************************************************************************** */
/*                                                                            */
/*                                                        :::      ::::::::   */
/*   server_handler.c                                   :+:      :+:    :+:   */
/*                                                    +:+ +:+         +:+     */
/*   By: jihi <jihi@student.42.fr>                  +#+  +:+       +#+        */
/*                                                +#+#+#+#+#+   +#+           */
/*   Created: 2026/02/15 02:39:12 by jihi              #+#    #+#             */
/*   Updated: 2026/02/15 19:45:29 by jihi             ###   ########.fr       */
/*                                                                            */
/* ************************************************************************** */

#include "minitalk.h"

static void	reset_state(pid_t *curr_pid, int *bit, unsigned char *c, pid_t pid)
{
	*curr_pid = pid;
	*bit = 0;
	*c = 0;
}

static void	print_char(unsigned char c)
{
	if (c == 0)
		write(1, "\n", 1);
	else
		write(1, &c, 1);
}

static void	handle_bit(int sig, int *bit, unsigned char *c)
{
	*c <<= 1;
	if (sig == SIGUSR2)
		*c |= 1;
	(*bit)++;
}

static void	handler(int sig, siginfo_t *info, void *context)
{
	static pid_t			curr_pid = 0;
	static int				bit = 0;
	static unsigned char	c = 0;

	(void)context;
	if (!info)
		return ;
	if (curr_pid == 0 || curr_pid != info->si_pid)
		reset_state(&curr_pid, &bit, &c, info->si_pid);
	handle_bit(sig, &bit, &c);
	if (bit == 8)
	{
		print_char(c);
		if (c == 0)
			curr_pid = 0;
		bit = 0;
		c = 0;
	}
	if (info->si_pid > 0)
		kill(info->si_pid, SIGUSR1);
}

void	server_get_handler(struct sigaction *sa)
{
	sa->sa_sigaction = handler;
	sigemptyset(&sa->sa_mask);
	sigaddset(&sa->sa_mask, SIGUSR1);
	sigaddset(&sa->sa_mask, SIGUSR2);
	sa->sa_flags = SA_SIGINFO;
}
