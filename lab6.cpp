#define _CRT_SECURE_NO_WARNINGS
#include <windows.h>
#include <iostream>
#include <stdio.h>
#include <math.h>
#include <stdlib.h>
#include <time.h>

#define SIZE 10
#define TIMES 10000000
using namespace std;



int main()
{
	srand(time(NULL));
	int flag = 1;
	double zero = 0.0;
	clock_t begin, end;

	do
	{
		int count = 0;
		double arr[SIZE];
		double resultArrC[SIZE] = {0,0,0,0,0,0,0,0,0,0};
		double resultArrFPU[SIZE]= { 0,0,0,0,0,0,0,0,0,0 };

		try {
			printf("Fill the array:\n");
			for (int i = 0; i < SIZE; i++)
			{
				printf("\tarr[%d] = ", i);
				while (!scanf("%lf", &arr[i]))
					rewind(stdin);
				rewind(stdin);
			}

			//C algorithm
			begin = clock();
			for (int num = 0; num < TIMES; num++)
			{
				for (int i = 0; i < SIZE; i++)
				{
					if (arr[i] < 0)
					{
						resultArrC[i] = pow(arr[i], 2);
					}
					else
					{
						resultArrC[i] = pow(arr[i], 3);
					}
				}
			}
			end = clock();
			printf("\nResult array of C algorithm:\n"
				"----------------------------\n");
			for (int i = 0; i < SIZE; i++)
			{
				printf("%.3lf  \n", resultArrC[i]);
			}
			printf("time of C algorithm : %.6lf seconds\n\n", (double)(end - begin) / CLOCKS_PER_SEC);

			//FPU algorithm
			begin = clock();
			for (int num = 0; num < TIMES; num++)
			{
				double sizeOfArr = SIZE;
				double step = 1;
				double i = 0;
				_asm
				{
					finit;						//������������� ������������
					fld sizeOfArr				//�������� � ���� �������� sizeOfArr
					mov esi, 0					//�������� esi
					fld i;						//�������� � ���� �������� i
				loop_start:
					fcom	 					//���������� ST(0) � ST(1)
					fstsw ax					//� ax - ������� ���������
					and ah, 01000101b			//== ��������� ��� 8(�0), 10(C2)
					je loop_end					// ���� 0 - ����� �����

	
						
					
					fld[arr + esi]				//�������� ����� � ���� ������� �������
					fcom zero
					fstsw ax					//� ax - ������� ���������
					and ah, 01000101b;			//>0 ��������� ���� 8(�0), 10(�2), 14(c3)
					je greaterZ					//���� ZF = 1
					jmp lessZ					//���� ZF != 1
				greaterZ:
					fmul[arr + esi]				//ST(0)*arr[esi], ��������� � ST(0), �������� � �������
					fstsw ax					
					and al, 00001000b			
					jne overflow				//��������� ���� OE
					fmul[arr + esi]				//ST(0)*arr[esi], ��������� � ST(0), �������� � ���
					fstsw ax
					and al, 00001000b
					jne overflow
					fstp[resultArrFPU + esi]	//������� ��������� � ������ � ������������ � ������������� �� �����
					jmp next_step;
				lessZ:
					fmul[arr + esi]				//ST(0)*arr[esi], ��������� � ST(0), �������� � �������
					fstsw ax
					and al, 00001000b
					jne overflow
					fstp[resultArrFPU + esi]	//������� ��������� � ������ � ������������ � ������������� �� �����
					jmp next_step
				next_step:
					fadd step
					fst i						//���������� ������� ����� � i
					add esi, 8					//esi += 8, �.�. �������� � ����� ������ double
					jmp loop_start
				overflow:
					fwait
				}
				throw new overflow_error("Overflow!");
				_asm
				{
				loop_end:
					fwait
				}
			}

			end = clock();
			printf("Result array of FPU algorithm:\n"
				"----------------------------\n");
			for (int i = 0; i < SIZE; i++)
			{
				printf("%.3lf  \n", resultArrFPU[i]);
			}
			printf("time of FPU algorithm : %.6lf seconds\n\n", (double)(end - begin) / CLOCKS_PER_SEC);

		}
		catch (overflow_error ex) 
		{
			cout << ex.what() << endl;
			break;
		}
		catch (...)
		{
			cout << "Wrong input!" << endl;
			break;
		}

		system("pause");
		system("CLS");
	} while (flag);
	system("cls");
	system("pause");
	return 0;
}