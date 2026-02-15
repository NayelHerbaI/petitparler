/* ************************************************************************** */
/*                                                                            */
/*                                                        :::      ::::::::   */
/*   client_send.c                                      :+:      :+:    :+:   */
/*                                                    +:+ +:+         +:+     */
/*   By: jihi <jihi@student.42.fr>                  +#+  +:+       +#+        */
/*                                                +#+#+#+#+#+   +#+           */
/*   Created: 2026/02/15 02:38:47 by jihi              #+#    #+#             */
/*   Updated: 2026/02/15 02:43:09 by jihi             ###   ########.fr       */
/*                                                                            */
/* ************************************************************************** */

#include "minitalk.h"

static int	send_sig(int pid, int sig)
{
	if (kill(pid, sig) == -1)
		return (-1);
	return (0);
}

static int	send_bit(int pid, int bit)
{
	if (bit)
	{
		if (send_sig(pid, SIGUSR2) == -1)
			return (-1);
	}
	else
	{
		if (send_sig(pid, SIGUSR1) == -1)
			return (-1);
	}
	wait_ack();
	return (0);
}

int	send_char(int pid, unsigned char c)
{
	int	i;

	i = 7;
	while (i >= 0)
	{
		if (send_bit(pid, (c >> i) & 1) == -1)
			return (-1);
		i--;
	}
	return (0);
}
