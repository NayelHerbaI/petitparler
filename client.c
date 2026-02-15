/* ************************************************************************** */
/*                                                                            */
/*                                                        :::      ::::::::   */
/*   client.c                                           :+:      :+:    :+:   */
/*                                                    +:+ +:+         +:+     */
/*   By: jihi <jihi@student.42.fr>                  +#+  +:+       +#+        */
/*                                                +#+#+#+#+#+   +#+           */
/*   Created: 2026/02/15 02:37:53 by jihi              #+#    #+#             */
/*   Updated: 2026/02/15 02:37:54 by jihi             ###   ########.fr       */
/*                                                                            */
/* ************************************************************************** */

#include "minitalk.h"

int	usage(void)
{
	ft_putstr("Usage: ./client <PID> <Message>\n");
	return (-1);
}

int	main(int ac, char **av)
{
	int	pid;
	int	i;

	if (ac != 3)
		return (usage());
	pid = parse_pid(av[1]);
	if (pid == -1)
		return (-1);
	setup_ack_signal();
	i = 0;
	while (av[2][i])
	{
		if (send_char(pid, (unsigned char)av[2][i++]) == -1)
			return (-1);
	}
	if (send_char(pid, 0) == -1)
		return (-1);
	return (0);
}
