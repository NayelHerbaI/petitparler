/* ************************************************************************** */
/*                                                                            */
/*                                                        :::      ::::::::   */
/*   client_ack.c                                       :+:      :+:    :+:   */
/*                                                    +:+ +:+         +:+     */
/*   By: jihi <jihi@student.42.fr>                  +#+  +:+       +#+        */
/*                                                +#+#+#+#+#+   +#+           */
/*   Created: 2026/02/15 02:38:08 by jihi              #+#    #+#             */
/*   Updated: 2026/02/15 19:49:57 by jihi             ###   ########.fr       */
/*                                                                            */
/* ************************************************************************** */

#include "minitalk.h"

static volatile sig_atomic_t	g_ack = 0;

static void	acknowledge_handler(int sig)
{
	(void)sig;
	g_ack = 1;
}

void	wait_ack(void)
{
	while (!g_ack)
		pause();
	g_ack = 0;
}

void	setup_ack_signal(void)
{
	struct sigaction	sa;

	sa.sa_handler = acknowledge_handler;
	sigemptyset(&sa.sa_mask);
	sa.sa_flags = 0;
	sigaction(SIGUSR1, &sa, NULL);
}

int	parse_pid(char *s)
{
	int	pid;

	if (!ft_isdigits(s))
		return (-1);
	pid = ft_atoi(s);
	if (pid <= 0)
		return (-1);
	if (kill(pid, 0) == -1)
		return (-1);
	return (pid);
}
